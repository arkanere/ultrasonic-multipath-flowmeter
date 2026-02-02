CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2
LDFLAGS = -lm

SOURCES = flowmeter.c main.c
OBJECTS = $(SOURCES:.c=.o)
EXECUTABLE = flowmeter

.PHONY: all clean

all: $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f $(OBJECTS) $(EXECUTABLE)

.PHONY: run
run: $(EXECUTABLE)
	./$(EXECUTABLE)
