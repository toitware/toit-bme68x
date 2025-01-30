// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import expect show *
import gpio
import i2c
import bme68x

/**
Smoke test for the bme68x driver.

For this test the sensor is expected to be indoors with the temperature being in
  range 17-30 degrees Celsius.
*/

SDA-PIN-NUMBER ::= 21
SCL-PIN-NUMBER ::= 22

main:
  bus := i2c.Bus
    --sda=gpio.Pin SDA-PIN-NUMBER
    --scl=gpio.Pin SCL-PIN-NUMBER

  device := bus.device bme68x.Bme68x.I2C-ADDRESS
  sensor := bme68x.Bme68x device

  sensor.on

  measurements := []
  measurements.add sensor.read
  measurement := measurements.last
  print measurement
  expect 18 <= measurement.temperature <= 33
  expect 0 <= measurement.humidity <= 100
  expect 100_000 <= sensor.read-pressure <= 120_000
  // The gas measurement is completely wonky for the first ~300 measurements.
  // There is no good test for it.

  [
    bme68x.Bme68x.IIR-FILTER-SIZE-1,
    bme68x.Bme68x.IIR-FILTER-SIZE-3,
    bme68x.Bme68x.IIR-FILTER-SIZE-7,
    bme68x.Bme68x.IIR-FILTER-SIZE-15,
    bme68x.Bme68x.IIR-FILTER-SIZE-31,
    bme68x.Bme68x.IIR-FILTER-SIZE-63,
    bme68x.Bme68x.IIR-FILTER-SIZE-127,
    bme68x.Bme68x.IIR-FILTER-SIZE-0,
  ].do:
    sensor.iir-filter-size = it
    expect-equals it sensor.iir-filter-size
    measurements.add sensor.read

  OVERSAMPLINGS ::= [
    bme68x.Bme68x.OVERSAMPLING-X1,
    bme68x.Bme68x.OVERSAMPLING-X2,
    bme68x.Bme68x.OVERSAMPLING-X4,
    bme68x.Bme68x.OVERSAMPLING-X8,
    bme68x.Bme68x.OVERSAMPLING-X16,
  ]

  OVERSAMPLINGS.do:
    sensor.temperature-oversampling = it
    expect-equals it sensor.temperature-oversampling
    measurements.add sensor.read

  OVERSAMPLINGS.do:
    sensor.pressure-oversampling = it
    expect-equals it sensor.pressure-oversampling
    measurements.add sensor.read

  OVERSAMPLINGS.do:
    sensor.humidity-oversampling = it
    expect-equals it sensor.humidity-oversampling
    measurements.add sensor.read

  temperature-sum := 0
  pressure-sum := 0
  humidity-sum := 0
  measurements.do:
    temperature-sum += it.temperature
    pressure-sum += it.pressure
    humidity-sum += it.humidity
  temperature-average := temperature-sum / measurements.size
  pressure-average := pressure-sum / measurements.size
  humidity-average := humidity-sum / measurements.size

  temperature-different := false
  pressure-different := false
  humidity-different := false
  gas-different := false
  gas := null
  measurements.do:
    expect (temperature-average * 0.9) <= it.temperature <= temperature-average * 1.1
    expect (pressure-average * 0.9) <= it.pressure <= pressure-average * 1.1
    expect (humidity-average * 0.9) <= it.humidity <= humidity-average * 1.1
    if it.temperature != temperature-average: temperature-different = true
    if it.pressure != pressure-average: pressure-different = true
    if it.humidity != humidity-average: humidity-different = true
    if gas == null:
      gas = it.gas-resistance
    else if it.gas-resistance != gas:
      gas-different = true

  expect temperature-different
  expect pressure-different
  expect humidity-different
  expect gas-different

  sensor.off
  print "done"
