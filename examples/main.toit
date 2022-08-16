// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import i2c
import bme68x

SDA_PIN_NUMBER ::= 21
SCL_PIN_NUMBER ::= 22

main:
  bus := i2c.Bus
    --sda=gpio.Pin SDA_PIN_NUMBER
    --scl=gpio.Pin SCL_PIN_NUMBER

  device := bus.device bme68x.Bme68x.I2C_ADDRESS
  sensor := bme68x.Bme68x device

  sensor.on

  while true:
    // Read all sensor values at the same time.
    // Note that the gas resistance is not reliable in the first 300+ measurements.
    print sensor.read

    // Read the individual sensor values:
    print "temperature: $sensor.read_temperature"
    print "gas resistance: $sensor.read_gas_resistance Ohm"
    print "pressure: $sensor.read_pressure Pa"
    print "humidity: $sensor.read_humidity%"
    print

    sleep --ms=1_000
