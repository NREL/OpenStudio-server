#############################################################
# Create UUID 11/22/2013
# http://www.r-bloggers.com/generate-uuids-in-r/
#############################################################

uuid <- function(uppercase=FALSE) {
   hex_digits <- c(as.character(0:9), letters[1:6])
   hex_digits <- if (uppercase) toupper(hex_digits) else hex_digits
   y_digits <- hex_digits[9:12]
   paste(
     paste0(sample(hex_digits, 8), collapse=''),
     paste0(sample(hex_digits, 4), collapse=''),
     paste0('4', sample(hex_digits, 3), collapse=''),
     paste0(sample(y_digits,1),
       sample(hex_digits, 3),
       collapse=''),
     paste0(sample(hex_digits, 12), collapse=''),
     sep='-')}