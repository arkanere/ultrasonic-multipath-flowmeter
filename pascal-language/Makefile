FPC = fpc
FPFLAGS = -O2 -Mobjfpc -Sh -Fcutf8
PROGRAM = main.pas
EXECUTABLE = flowmeter

.PHONY: all clean run

all: $(EXECUTABLE)

$(EXECUTABLE): $(PROGRAM) flowmeter.pas
	$(FPC) $(FPFLAGS) -o$(EXECUTABLE) $(PROGRAM)

clean:
	rm -f *.o *.ppu $(EXECUTABLE)

run: $(EXECUTABLE)
	./$(EXECUTABLE)
