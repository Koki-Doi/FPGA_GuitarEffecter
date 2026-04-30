CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -pedantic -I..

TARGET := test_rat_style_distortion
SOURCES := test_rat_style_distortion.cpp ../src/effects/RatStyleDistortion.cpp

all: $(TARGET)

$(TARGET): $(SOURCES) ../src/effects/RatStyleDistortion.h
	$(CXX) $(CXXFLAGS) $(SOURCES) -o $(TARGET)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all run clean
