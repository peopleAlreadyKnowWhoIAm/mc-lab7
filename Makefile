DEVICE := atmega328p # From https://gcc.gnu.org/onlinedocs/gcc/AVR-Options.html
ARCH := avr5
TARGET := main

USB_UART := /dev/ttyUSB0

#SOURCES += src/main.c
SOURCE = main.s

#Toolchain

TOOLCHAIN := /usr/bin

CC := $(TOOLCHAIN)/avr-gcc
AS := $(TOOLCHAIN)/avr-as
LD := $(TOOLCHAIN)/avr-ld
OC := $(TOOLCHAIN)/avr-objcopy
OD := $(TOOLCHAIN)/objdump
OS := $(TOOLCHAIN)/avr-size

ASFLAGS := -mmcu=$(DEVICE)

LDFLAGS := -m$(ARCH)
LDFLAGS += -Tdata 0x800100

.PHONY: all clean

all: $(TARGET).hex

%.o: %.s
	$(AS) $(ASFLAGS) $< -o $@

%.elf: %.o
	$(LD) $< $(LDFLAGS) -o $@

%.hex: %.elf
	$(OC) -S -O ihex $< $@
	$(OS) $<

clean:
	rm *.o *.elf *.hex
flash: $(TARGET).hex
	avrdude -c arduino -P $(USB_UART) -p $(DEVICE) -U flash:w:$(TARGET).hex