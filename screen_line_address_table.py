

def print_table():
    for section in range(3):
        for char_line in range(8): 
            s1 = ""
            for char_pixel in range(8):
                # bottom 5 bites (0-31) are the character column
                # ...s sppp   lllw wwww
                address = 0xc000 + char_line * 32 + char_pixel * 256 + section * (256*8)
                s1 += "&%.2x, &%.2x,   " % (int(address/256), int(address % 256)) 
            s1 = s1.rstrip()
            s1 = s1.rstrip(",")
            print(" defb " + s1)

print_table()

