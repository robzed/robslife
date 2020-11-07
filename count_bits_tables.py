def  countSetBits(n): 
    count = 0
    while (n): 
        count += n & 1
        n >>= 1
    return count


def print_table():
    for k in range(0, 254, 8):
        s1 = ""
        for j in range(8):
            i = k+j
            s1 += str(countSetBits(i)) + ", "
        print(" .db " + s1 + " ; " + str(k) + "-" + str(k+7))


print_table()

