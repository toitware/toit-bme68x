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

SDA_PIN_NUMBER ::= 21
SCL_PIN_NUMBER ::= 22

main:
  bus := i2c.Bus
    --sda=gpio.Pin SDA_PIN_NUMBER
    --scl=gpio.Pin SCL_PIN_NUMBER

  device := bus.device bme68x.Bme68x.I2C_ADDRESS
  sensor := bme68x.Bme68x device

  sensor.on

  measurements := []
  measurements.add sensor.read
  measurement := measurements.last
  print measurement
  expect 18 <= measurement.temperature <= 33
  expect 0 <= measurement.humidity <= 100
  expect 100_000 <= sensor.read_pressure <= 120_000
  // The gas measurement is completely wonky for the first ~300 measurements.
  // There is no good test for it.

  [
    bme68x.Bme68x.IIR_FILTER_SIZE_1,
    bme68x.Bme68x.IIR_FILTER_SIZE_3,
    bme68x.Bme68x.IIR_FILTER_SIZE_7,
    bme68x.Bme68x.IIR_FILTER_SIZE_15,
    bme68x.Bme68x.IIR_FILTER_SIZE_31,
    bme68x.Bme68x.IIR_FILTER_SIZE_63,
    bme68x.Bme68x.IIR_FILTER_SIZE_127,
    bme68x.Bme68x.IIR_FILTER_SIZE_0,
  ].do:
    sensor.iir_filter_size = it
    expect_equals it sensor.iir_filter_size
    measurements.add sensor.read

  OVERSAMPLINGS ::= [
    bme68x.Bme68x.OVERSAMPLING_X1,
    bme68x.Bme68x.OVERSAMPLING_X2,
    bme68x.Bme68x.OVERSAMPLING_X4,
    bme68x.Bme68x.OVERSAMPLING_X8,
    bme68x.Bme68x.OVERSAMPLING_X16,
  ]

  OVERSAMPLINGS.do:
    sensor.temperature_oversampling = it
    expect_equals it sensor.temperature_oversampling
    measurements.add sensor.read

  OVERSAMPLINGS.do:
    sensor.pressure_oversampling = it
    expect_equals it sensor.pressure_oversampling
    measurements.add sensor.read

  OVERSAMPLINGS.do:
    sensor.humidity_oversampling = it
    expect_equals it sensor.humidity_oversampling
    measurements.add sensor.read

  temperature_sum := 0
  pressure_sum := 0
  humidity_sum := 0
  measurements.do:
    temperature_sum += it.temperature
    pressure_sum += it.pressure
    humidity_sum += it.humidity
  temperature_average := temperature_sum / measurements.size
  pressure_average := pressure_sum / measurements.size
  humidity_average := humidity_sum / measurements.size

  temperature_different := false
  pressure_different := false
  humidity_different := false
  gas_different := false
  gas := null
  measurements.do:
    expect (temperature_average * 0.9) <= it.temperature <= temperature_average * 1.1
    expect (pressure_average * 0.9) <= it.pressure <= pressure_average * 1.1
    expect (humidity_average * 0.9) <= it.humidity <= humidity_average * 1.1
    if it.temperature != temperature_average: temperature_different = true
    if it.pressure != pressure_average: pressure_different = true
    if it.humidity != humidity_average: humidity_different = true
    if gas == null:
      gas = it.gas_resistance
    else if it.gas_resistance != gas:
      gas_different = true

  expect temperature_different
  expect pressure_different
  expect humidity_different
  expect gas_different

  sensor.off
  print "done"
