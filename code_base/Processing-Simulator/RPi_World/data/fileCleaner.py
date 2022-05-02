fileName = input("File you need to clean: ")
file_read = open(fileName + ".txt", "r")


content = file_read.readlines()
content[len(content) - 1] = '@' # change \n at EOF to @
lastDelim = 0
badIndices = []

for i in range(0, len(content)):
    if('@' in content[i]):

        # Checks for and notifies about sections that are too long or short

        if i != 0 and (i - lastDelim) < 64: 
            print("TOO SHORT " + str(i) + " " + str(i - lastDelim))
            badIndices.append(i)
        if i != 0 and (i - lastDelim) > 64:
            print("TOO LONG " + str(i) + " " + str(i - lastDelim))
            badIndices.append(i)
        lastDelim = i

        
    if len(content[i]) > 6 and (not '@' in content[i]) or (len(content[i]) > 7):
        # Checks for and notifies about lines that contain too many characters
        print(i)

for index in sorted(badIndices, reverse=True):
    index = index - 1
    complete = False
    while not complete:
        if '@' in content[index]:
            complete = True
        del content[index]
        index = index - 1

content = content[:-1] # remove final @ that was required for length calcs

file_write = open(fileName + ".txt", "w")
    
file_write.writelines(content)