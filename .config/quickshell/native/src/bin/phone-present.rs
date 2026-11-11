//! Locks the session when your phone disconnects.
//!
//! Presence == the paired phone is connected over Bluetooth, according to BlueZ.
//! We subscribe to BlueZ's `PropertiesChanged` signal for the device, so a
//! disconnect locks the session immediately. While the phone is away we keep
//! asking BlueZ to reconnect, so it is noticed as soon as it is back in range.
//!
//! Whatever the lock command pauses or mutes (playerctl players, PulseAudio/PipeWire
//! sinks) is remembered and put back when logind reports the session was unlocked.
//!
//! Reports on stdout, one line per change: "present <label>" / "absent <label>".

use std::collections::HashMap;
use std::path::PathBuf;
use std::time::Duration;

use anyhow::{Context, Result, bail};
use clap::Parser;
use futures::StreamExt;
use serde::Deserialize;
use tokio::process::Command;
use zbus::zvariant::{OwnedObjectPath, OwnedValue};
use zbus::{Connection, proxy};

#[proxy(interface = "org.bluez.Device1", default_service = "org.bluez")]
trait Device1 {
    fn connect(&self) -> zbus::Result<()>;
    #[zbus(property)]
    fn connected(&self) -> zbus::Result<bool>;
}

type Objects = HashMap<OwnedObjectPath, HashMap<String, HashMap<String, OwnedValue>>>;

#[proxy(
    interface = "org.freedesktop.DBus.ObjectManager",
    default_service = "org.bluez",
    default_path = "/"
)]
trait BluezObjects {
    fn get_managed_objects(&self) -> zbus::Result<Objects>;
}

#[proxy(
    interface = "org.freedesktop.login1.Manager",
    default_service = "org.freedesktop.login1",
    default_path = "/org/freedesktop/login1"
)]
trait Login1 {
    fn get_session(&self, id: &str) -> zbus::Result<OwnedObjectPath>;
    fn get_session_by_pid(&self, pid: u32) -> zbus::Result<OwnedObjectPath>;
}

#[proxy(interface = "org.freedesktop.login1.Session", default_service = "org.freedesktop.login1")]
trait Session {
    #[zbus(signal)]
    fn unlock(&self) -> zbus::Result<()>;
}

/// Media state captured just before locking.
struct Snapshot {
    /// playerctl players that were playing
    players: Vec<String>,
    /// sinks that were not muted
    sinks: Vec<String>,
}

async fn run(prog: &str, args: &[&str]) -> String {
    Command::new(prog)
        .args(args)
        .output()
        .await
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default()
}

async fn snapshot() -> Snapshot {
    let mut players = Vec::new();
    for p in run("playerctl", &["-l"]).await.lines().filter(|l| !l.is_empty()) {
        if run("playerctl", &["-p", p, "status"]).await.trim() == "Playing" {
            players.push(p.to_string());
        }
    }
    let mut sinks = Vec::new();
    let mut name = None;
    for line in run("pactl", &["list", "sinks"]).await.lines() {
        let line = line.trim();
        if let Some(n) = line.strip_prefix("Name: ") {
            name = Some(n.to_string());
        } else if line == "Mute: no" {
            sinks.extend(name.take());
        }
    }
    Snapshot { players, sinks }
}

async fn restore(snap: Snapshot) {
    for s in &snap.sinks {
        run("pactl", &["set-sink-mute", s, "0"]).await;
    }
    for p in &snap.players {
        run("playerctl", &["-p", p, "play"]).await;
    }
}

async fn session_path(conn: &Connection) -> Result<OwnedObjectPath> {
    let login = Login1Proxy::new(conn).await?;
    if let Ok(id) = std::env::var("XDG_SESSION_ID") {
        if let Ok(p) = login.get_session(&id).await {
            return Ok(p);
        }
    }
    login.get_session_by_pid(std::process::id()).await.context("cannot find the logind session")
}

#[derive(Parser, Debug)]
#[command(version, about = "Lock the session when your phone disconnects")]
struct Args {
    /// Shell config file [default: ~/.config/quickshell/config.json]. Settings live
    /// under its "phone_present" key; the flags below override them.
    #[arg(short, long)]
    config: Option<PathBuf>,

    /// Bluetooth MAC address of the (paired) phone, e.g. 3C:B0:ED:16:24:6D
    #[arg(short, long)]
    mac: Option<String>,

    /// Display name used in the status line (default: the MAC)
    #[arg(short, long)]
    name: Option<String>,

    /// Seconds between reconnect attempts while the phone is away [default: 5]
    #[arg(short, long)]
    interval: Option<u64>,

    /// Shell command that locks the session [default: loginctl lock-session]
    #[arg(short, long)]
    lock_cmd: Option<String>,
}

/// The "phone_present" section of the shell config.
#[derive(Deserialize, Debug, Default)]
#[serde(deny_unknown_fields)]
struct Section {
    mac: Option<String>,
    name: Option<String>,
    interval: Option<u64>,
    lock_cmd: Option<String>,
}

/// Whole-shell config; other sections belong to other parts of the shell.
#[derive(Deserialize, Debug, Default)]
struct ShellConfig {
    phone_present: Option<Section>,
}

fn load_section(explicit: Option<PathBuf>) -> Result<Section> {
    let path = explicit.clone().unwrap_or_else(|| {
        let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
        home.join(".config/quickshell/config.json")
    });
    match std::fs::read_to_string(&path) {
        Ok(text) => Ok(serde_json::from_str::<ShellConfig>(&text)
            .with_context(|| format!("invalid config {}", path.display()))?
            .phone_present
            .unwrap_or_default()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound && explicit.is_none() => Ok(Section::default()),
        Err(e) => Err(e).with_context(|| format!("cannot read config {}", path.display())),
    }
}

async fn find_device(conn: &Connection, mac: &str) -> Result<OwnedObjectPath> {
    let objects = BluezObjectsProxy::new(conn)
        .await?
        .get_managed_objects()
        .await
        .context("cannot reach BlueZ (is bluetooth.service running?)")?;
    for (path, ifaces) in objects {
        let Some(props) = ifaces.get("org.bluez.Device1") else { continue };
        let addr = props.get("Address").and_then(|v| <&str>::try_from(v).ok());
        if addr.is_some_and(|a| a.eq_ignore_ascii_case(mac)) {
            return Ok(path);
        }
    }
    bail!("{mac} is not a known Bluetooth device: pair the phone first")
}

async fn lock(cmd: &str) {
    match Command::new("sh").arg("-c").arg(cmd).status().await {
        Ok(st) if st.success() => {}
        Ok(st) => eprintln!("lock command exited with {st}"),
        Err(e) => eprintln!("failed to run lock command: {e}"),
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    let cfg = load_section(args.config)?;
    let Some(mac) = args.mac.or(cfg.mac) else {
        bail!("no phone MAC: set phone_present.mac in ~/.config/quickshell/config.json or pass --mac");
    };
    let label = args.name.or(cfg.name).unwrap_or_else(|| mac.clone());
    let retry = Duration::from_secs(args.interval.or(cfg.interval).unwrap_or(5).max(1));
    let lock_cmd = args.lock_cmd.or(cfg.lock_cmd).unwrap_or_else(|| "loginctl lock-session".into());

    let conn = Connection::system().await.context("cannot connect to the system bus")?;
    let path = find_device(&conn, &mac).await?;
    let dev = Device1Proxy::builder(&conn).path(path)?.build().await?;
    let mut changes = dev.receive_connected_changed().await;
    let session = SessionProxy::builder(&conn).path(session_path(&conn).await?)?.build().await?;
    let mut unlocks = session.receive_unlock().await?;
    let mut saved: Option<Snapshot> = None;

    let mut present: Option<bool> = None;
    // Report a state; lock on every transition to absent.
    macro_rules! set {
        ($now:expr) => {{
            let now: bool = $now;
            if present != Some(now) {
                present = Some(now);
                println!("{} {label}", if now { "present" } else { "absent" });
                if !now {
                    // Keep the first snapshot until unlock, so a second disconnect
                    // doesn't record the already-paused state.
                    if saved.is_none() {
                        saved = Some(snapshot().await);
                    }
                    lock(&lock_cmd).await;
                }
            }
        }};
    }

    // Startup: if the phone isn't connected, give BlueZ one chance to reach it.
    if !dev.connected().await? {
        let _ = tokio::time::timeout(Duration::from_secs(12), dev.connect()).await;
    }
    set!(dev.connected().await?);

    let mut tick = tokio::time::interval(retry);
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);

    loop {
        tokio::select! {
            _ = tokio::signal::ctrl_c() => break,

            Some(change) = changes.next() => {
                if let Ok(now) = change.get().await {
                    set!(now);
                }
            }

            Some(_) = unlocks.next() => {
                if let Some(snap) = saved.take() {
                    restore(snap).await;
                }
            }

            _ = tick.tick(), if present == Some(false) => {
                // Signals report the result; just ask BlueZ to try again.
                let _ = tokio::time::timeout(Duration::from_secs(12), dev.connect()).await;
            }
        }
    }
    Ok(())
}
