CXX = g++
CXXFLAGS = -Wall -Wextra -std=c++17 -O2

SOURCES = flowmeter.cpp main.cpp
OBJECTS = $(SOURCES:.cpp=.o)
EXECUTABLE = flowmeter

.PHONY: all clean

all: $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $<

clean:
	rm -f $(OBJECTS) $(EXECUTABLE)

.PHONY: run
run: $(EXECUTABLE)
	./$(EXECUTABLE)
