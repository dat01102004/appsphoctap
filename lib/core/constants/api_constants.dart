class ApiConstants {
static const bool useNgrok = true;

static const String ngrokBase = "https://lael-nonexpanding-matronly.ngrok-free.dev";
static const String lanBase = "http://192.168.1.5:8000";

static String get baseUrl => useNgrok ? ngrokBase : lanBase;
}