CC = gcc
CFLAGS = -Wall -Wextra
LDFLAGS = -lfxp -lm

SRCS = generate.c gemm.c
OBJS = $(SRCS:.c=.o)
TARGET = gemm_test

all: $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $@ $(LDFLAGS)

clean:
	rm -f $(OBJS) $(TARGET) output.data

.PHONY: all clean 