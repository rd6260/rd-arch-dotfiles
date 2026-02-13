Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => NewScreen()),
  (Route<dynamic> route) => false, // Remove all routes
)
