import serial

ser = serial.Serial('COM7', 115200, timeout=0.050)

fileName = input("Please enter the name of the scenario: ")
file = open(fileName + ".txt", "w")
toWrite = b''

try:

	while True:
	
		while ser.in_waiting: 
		
			toWrite = toWrite + ser.readline()


except KeyboardInterrupt: 
	pass

toWrite = toWrite.decode("utf-8")
file.write(toWrite)

