FBC = fbc
FBFLAGS = -w all
SOURCES = main.bas flowmeter.bas
EXECUTABLE = flowmeter

.PHONY: all clean run

all: $(EXECUTABLE)

$(EXECUTABLE): $(SOURCES) flowmeter.bi
	$(FBC) $(FBFLAGS) $(SOURCES) -x $(EXECUTABLE)

clean:
	rm -f *.o $(EXECUTABLE)

run: $(EXECUTABLE)
	./$(EXECUTABLE)
