#[derive(Clone, Debug)]
pub struct LrcLine {
    pub time_ms: u64,
    pub text: String,
}

pub fn parse(input: &str) -> Vec<LrcLine> {
    let mut lines = Vec::new();
    
    for line in input.lines() {
        let line = line.trim();
        let mut current_idx = 0;
        let mut times = Vec::new();
        
        while current_idx < line.len() {
            if line[current_idx..].starts_with('[') {
                if let Some(end_idx) = line[current_idx..].find(']') {
                    let tag = &line[current_idx + 1..current_idx + end_idx];
                    
                    if let Some(colon_idx) = tag.find(':') {
                        let mm_str = &tag[..colon_idx];
                        if mm_str.chars().all(|c| c.is_ascii_digit()) {
                            let rest = &tag[colon_idx + 1..];
                            if let Some(dot_idx) = rest.find('.') {
                                let ss_str = &rest[..dot_idx];
                                let cs_str = &rest[dot_idx + 1..];
                                
                                if let (Ok(mm), Ok(ss), Ok(cs)) = (
                                    mm_str.parse::<u64>(),
                                    ss_str.parse::<u64>(),
                                    cs_str.parse::<u64>(),
                                ) {
                                    let ms = if cs_str.len() == 3 {
                                        cs
                                    } else if cs_str.len() == 2 {
                                        cs * 10
                                    } else {
                                        0
                                    };
                                    let time_ms = mm * 60000 + ss * 1000 + ms;
                                    times.push(time_ms);
                                }
                            }
                        }
                    }
                    current_idx += end_idx + 1;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        
        if !times.is_empty() {
            let text = line[current_idx..].trim().to_string();
            for t in times {
                lines.push(LrcLine {
                    time_ms: t,
                    text: text.clone(),
                });
            }
        }
    }
    
    lines.sort_by_key(|l| l.time_ms);
    lines
}
