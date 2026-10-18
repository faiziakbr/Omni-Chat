/// RTDB keys can't contain '.', '#', '$', '[' or ']'. Emails only hit '.'.
String emailKey(String email) => email.trim().toLowerCase().replaceAll('.', ',');
