// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be found
// in the LICENSE file.

// BME680 data sheet: https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bme680-ds001.pdf
// BME688 data sheet: https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bme688-ds000.pdf

import binary
import serial.device as serial
import serial.registers as serial

/**
Package for the BME680 and BME688 sensors.

Use $Bme68x.read to read all measurements at once from the sensor.
Use $Bme68x.read-temperature, $Bme68x.read-pressure, $Bme68x.read-humidity,
  $Bme68x.read-gas-resistance to read individual measurements.
*/

/**
A class that groups all measurements of the sensor.
*/
class Measurement:
  /** The temperature in degrees Celsius. */
  temperature/float
  /** The pressure in Pascal. */
  pressure/float
  /** The humidity in percent. */
  humidity/float
  /**
  The gas resistance in Ohms.
  Null, if no valid heater-configuration is set.
  */
  gas-resistance/float?

  constructor --.temperature --.pressure --.humidity --.gas-resistance:

  stringify -> string:
    str := "$(%.3f temperature)°C, $(%.3f pressure)Pa, $(%.3f humidity)%"
    if gas-resistance: str += ", $gas-resistance Ohm"
    return str

/**
A driver for the BME680 and BME688 sensors.
*/
class Bme68x:
  static I2C-ADDRESS     ::= 0x76
  static I2C-ADDRESS-ALT ::= 0x77

  static BME680-VARIANT_ ::= 0
  static BME688-VARIANT_ ::= 1

  /** Disables the IIR filter. */
  static IIR-FILTER-SIZE-0   ::= 0
  /** An IIR filter coefficient of 1 */
  static IIR-FILTER-SIZE-1   ::= 1
  /** An IIR filter coefficient of 3 */
  static IIR-FILTER-SIZE-3   ::= 3
  /** An IIR filter coefficient of 7 */
  static IIR-FILTER-SIZE-7   ::= 7
  /** An IIR filter coefficient of 15 */
  static IIR-FILTER-SIZE-15  ::= 15
  /** An IIR filter coefficient of 31 */
  static IIR-FILTER-SIZE-31  ::= 31
  /** An IIR filter coefficient of 63 */
  static IIR-FILTER-SIZE-63  ::= 63
  /** An IIR filter coefficient of 127 */
  static IIR-FILTER-SIZE-127 ::= 127

  /** Oversampling by a factor of 1x. */
  static OVERSAMPLING-X1   ::= 1
  /** Oversampling by a factor of 2x. */
  static OVERSAMPLING-X2   ::= 2
  /** Oversampling by a factor of 4x. */
  static OVERSAMPLING-X4   ::= 4
  /** Oversampling by a factor of 8x. */
  static OVERSAMPLING-X8   ::= 8
  /** Oversampling by a factor of 16x. */
  static OVERSAMPLING-X16  ::= 16

  static CTRL-MEAS-REGISTER_ ::= 0x74
  // Gives the variant ID of this chip.
  // The BME680 doesn't have this register.
  static VARIANT-ID-REGISTER_ ::= 0xF0

  // Bme680, section 5.3.2.4
  // Bme688, section 5.3.3.4
  static IIR-FILTER-SIZE-REGISTER_ ::= 0x75
  static IIR-FILTER-SIZE-MASK_ ::= 0x1C

  // Bme680, section 5.3.2.1
  // Bme688, section 5.3.3.1
  static HUMIDITY-OVERSAMPLING-REGISTER_ ::= 0x72
  static HUMIDITY-OVERSAMPLING-MASK_ ::= 0x07

  // Bme680, section 5.3.2.2
  // Bme688, section 5.3.3.2
  static TEMPERATURE-OVERSAMPLING-REGISTER_ ::= 0x74
  static TEMPERATURE-OVERSAMPLING-MASK_ ::= 0x70

  // Bme680, section 5.3.2.3
  // Bme688, section 5.3.3.3
  static PRESSURE-OVERSAMPLING-REGISTER_ ::= 0x74
  static PRESSURE-OVERSAMPLING-MASK_ ::= 0x1C

  // Temperature registers.
  // Bme680, section 3.3.1, table 11.
  // Bme688, section 3.6.1, table 13
  static TEMPERATURE-ADC-REGISTER_ ::= 0x22 // 20 bits. (Reg_0x24 & 0xF0)=LSB.
  // Calibration:
  static PAR-T1-REGISTER_ ::=  0xE9  // 16 bits. 0xEA=MSB.
  static PAR-T2-REGISTER_ ::=  0x8A  // 16 bits. 0x8B=MSB.
  static PAR-T3-REGISTER_ ::=  0x8C  // 8 bits.

  // Pressure registers.
  // BME680, section 3.3.2, table 12.
  // BME688, section 3.6.2, table 14
  static PRESSURE-ADC-REGISTER_ ::= 0x1F // 20 bits. (Reg_0x21 & 0xF0)=LSB
  // Calibration:
  static PAR-P1-REGISTER_ ::=  0x8E  // 16 bits. 0x8F=MSB.
  static PAR-P2-REGISTER_ ::=  0x90  // 16 bits. 0x91=MSB.
  static PAR-P3-REGISTER_ ::=  0x92  // 8 bits.
  static PAR-P4-REGISTER_ ::=  0x94  // 16 bits. 0x95=MSB.
  static PAR-P5-REGISTER_ ::=  0x96  // 16 bits. 0x97=MSB.
  static PAR-P6-REGISTER_ ::=  0x99  // 8 bits.
  static PAR-P7-REGISTER_ ::=  0x98  // 8 bits.
  static PAR-P8-REGISTER_ ::=  0x9C  // 16 bits. 0x9D=MSB.
  static PAR-P9-REGISTER_ ::=  0x9E  // 16 bits. 0x9F=MSB.
  static PAR-P10-REGISTER_ ::= 0xA0  // 8 bits.

  // Humidity registers.
  // BME680, section 3.3.3, table 13.
  // BME688, section 3.6.3, table 15
  static HUMIDITY-ADC-REGISTER_ ::= 0x25 // 16 bits. 0x26=LSB.
  // Calibration:
  static PAR-H1-LSB-REGISTER_ ::= 0xE2  // Shared with PAR_H2_LSB_REGISTER_. Lower nibble.
  static PAR-H1-MSB-REGISTER_ ::= 0xE3
  static PAR-H2-LSB-REGISTER_ ::= 0xE2  // Shared with PAR_H1_LSB_REGISTER_. Higher nibble.
  static PAR-H2-MSB-REGISTER_ ::= 0xE1
  static PAR-H3-REGISTER_ ::= 0xE4
  static PAR-H4-REGISTER_ ::= 0xE5
  static PAR-H5-REGISTER_ ::= 0xE6
  static PAR-H6-REGISTER_ ::= 0xE7
  static PAR-H7-REGISTER_ ::= 0xE8

  // Gas registers.
  // BME680, section 3.4.1, table 15.
  static BME680-GAS-ADC-REGISTER_ ::= 0x2A // 10 bits. 0x2A=MSB. (Reg_0x2B & 0xC0)=LSB, shared with range.
  static BME680-GAS-RANGE-REGISTER_ ::= 0x2B // Shared with ADC. Lower nibble.
  // BME688, section 3.6.5, table 16, 3.7.1, table 17
  static BME688-GAS-ADC-REGISTER_ ::= 0x2C // 10 bits. 0x2C=MSB. (Reg_0x2D & 0xC0)=LSB, shared with range.
  static BME688-GAS-RANGE-REGISTER_ ::= 0x2D // Shared with ADC. Lower nibble.
  // Same for BME680 and BME688.
  // Calibration:
  static PAR-G1-REGISTER_ ::= 0xED // 8 bits.
  static PAR-G2-REGISTER_ ::= 0xEB // 16 bits. 0xEC=MSB.
  static PAR-G3-REGISTER_ ::= 0xEE // 8 bits.
  // According to datasheet
  static RES-HEAT-VAL-REGISTER_ ::= 0x00    // 8 bits.
  static RES-HEAT-RANGE-REGISTER_ ::= 0x02  // Mask 0x30.
  // BME680, section 3.4.1.
  static BME680-RANGE-SWITCHING-ERROR-REGISTER_ ::= 0x04  // Signed. 4 bit with mask 0xF0.
  // BME680, BME688, section 5.2
  static GAS-DISABLE-REGISTER_ ::= 0x70
  static GAS-DISABLE-MASK_ ::= 0x08
  static GAS-RUN-GAS-REGISTER_ ::= 0x71
  static BME680-RUN-GAS-MASK_ ::= 0x10
  static BME688-RUN-GAS-MASK_ ::= 0x20
  static GAS-VALID-MASK_ ::= 0x20
  static HEAT-STAB-MASK_ ::= 0x10
  // Registers of the first gas sensor heater set-point.
  // Resistance register of the first set-point.
  static GAS-HEATER-RESISTANCE-REGISTER_ ::= 0x5A
  // Wait register of the first set-point.
  static GAS-HEATER-WAIT-REGISTER_ ::= 0x64

  static GAS-SET-POINT-REGISTER_ ::= 0x71
  static GAS-SET-POINT-MASK_ ::= 0x0F

  static MODE-REGISTER_ ::= CTRL-MEAS-REGISTER_
  static MODE-MASK_ ::= 0x03

  // The status register indicating whether a measurement is in progress or new data is available.
  static MEAS-STATUS-REGISTER_ ::= 0x1D
  static NEW-DATA-MASK_ ::= 0x80
  static MEASURING-MASK_ ::= 0x60

  // ADC Ranges used for gas resistance calculations.
  // Section 3.4.1, table 16.
  static CONST-ARRAY1_ ::= [1.0, 1.0, 1.0, 1.0, 1.0, 0.99, 1.0, 0.992,
                            1.0, 1.0, 0.998, 0.995, 1.0, 0.99, 1.0, 1.0]
  static CONST-ARRAY2_ ::= [8000000.0, 4000000.0, 2000000.0, 1000000.0,
                            499500.4995, 248262.1648, 125000.0, 63004.03226,
                            31281.28128, 15625.0, 7812.5, 3906.25,
                            1953.125, 976.5625, 488.28125, 244.140625]

  registers_/serial.Registers ::= ?

  variant_/int := -1
  calibration_/Calibration_? := null

  /**
  The time the gas measurement should wait for. We use this to not poll the sensor too eagerly.
  */
  gas-wait-time-ms_/int := 0
  /** The gas_range that is currently configured. Needed to convert the ADC value to Ohms. */
  gas-range_/int := 0

  constructor dev/serial.Device:
    registers_ = dev.registers

  /**
  Initializes the sensor.

  See $Bme68x.iir-filter-size for information on $iir-filter-size.
  See $Bme68x.humidity-oversampling for information on $humidity-oversampling.
  See $Bme68x.temperature-oversampling for information on $temperature-oversampling.
  See $Bme68x.pressure-oversampling for information on $pressure-oversampling.
  See $set-gas-heater for information on $gas-degrees and $gas-ms.
  */
  on -> none
      --iir-filter-size/int=IIR-FILTER-SIZE-3
      --humidity-oversampling/int=OVERSAMPLING-X2
      --pressure-oversampling/int=OVERSAMPLING-X4
      --temperature-oversampling/int=OVERSAMPLING-X8
      --gas-degrees/int=320 --gas-ms/int=150:
    if variant_ != -1: throw "ALREADY_ON"

    variant_ = BME680-VARIANT_
    catch:
      variant := registers_.read-u8 VARIANT-ID-REGISTER_
      if variant != 0 and variant != 1: throw "Unknown BME68x variant"
      variant_ = variant

    calibration_ = read-calibration_

    // Do a default configuration.
    this.iir-filter-size = iir-filter-size
    this.humidity-oversampling = humidity-oversampling
    this.temperature-oversampling = temperature-oversampling
    this.pressure-oversampling = pressure-oversampling
    set-gas-heater --degrees=gas-degrees --ms=gas-ms
    // Sleep to give the gas heater time to reach the set-point.
    if gas-degrees != 0 and gas-ms != 0: sleep --ms=500

  off:
    // Make sure the device is in idle mode and disable the gas heater.
    disable-gas_
    set-bits_ MODE-REGISTER_ MODE-MASK_ 0x00
    variant_ = -1

  /**
  Takes one measurement and returns the result.
  */
  read -> Measurement:
    do-measurement_
    temperature := extract-temperature_
    raw-pressure := extract-pressure_ --raw
    pressure := pressure-raw-to-compensated_ raw-pressure temperature
    raw-humidity := extract-humidity_ --raw
    humidity := humidity-raw-to-compensated_ raw-humidity temperature
    gas-resistance := is-gas-enabled_ ? extract-gas-resistance_ : null
    return Measurement
        --temperature=temperature
        --pressure=pressure
        --humidity=humidity
        --gas-resistance=gas-resistance

  /**
  Reads the temperature and returns it in degrees Celsius.
  */
  read-temperature -> float:
    do-measurement_ --skip-gas
    return extract-temperature_

  extract-temperature_:
    raw := extract-temperature_ --raw
    return temperature-raw-to-compensated_ raw

  /**
  Reads the temperature and returns the raw ADC value.
  */
  read-temperature --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do-measurement_ --skip-gas
    return extract-temperature_ --raw

  extract-temperature_ --raw/bool -> int:
    // BME680, section 5.3.4.2
    // BME688, section 5.3.5.2
    raw-value := registers_.read-u24-be TEMPERATURE-ADC-REGISTER_
    raw-value >>= 4
    // Note that the least-significant 4 bits are only meaningful if oversampling is enabled.
    return raw-value

  /**
  Converts the temperature ADC value to a compensated temperature value.
  */
  temperature-raw-to-compensated_ raw/int -> float:
    // Use the same names as in the formula in the datasheet.
    temp-adc := raw
    par-t1 := calibration_.par-t1
    par-t2 := calibration_.par-t2
    par-t3 := calibration_.par-t3

    // BME680, section 3.3.1.
    // BME688, section 3.6.1.
    var1 := (temp-adc / 16384.0 - par-t1 / 1024.0) * par-t2
    temp-adc-div-131073 := temp-adc / 131072.0
    par-t1-div-8192 := par-t1 / 8192.0
    var2 := temp-adc-div-131073 - par-t1-div-8192
    var2 *= var2
    var2 *= par-t3 * 16.0
    t-fine := var1 + var2
    return t-fine / 5120.0

  /**
  Reads the barometric pressure and returns it in Pascals.
  */
  read-pressure -> float:
    do-measurement_ --skip-gas
    return extract-pressure_

  extract-pressure_:
    temperature := extract-temperature_
    raw-pressure := extract-pressure_ --raw
    return pressure-raw-to-compensated_ raw-pressure temperature

  /**
  Reads the barometric pressure and returns the raw sensor value.
  */
  read-pressure --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do-measurement_ --skip-gas
    return extract-pressure_ --raw

  extract-pressure_ --raw/bool -> int:
    raw-pressure := registers_.read-u24-be PRESSURE-ADC-REGISTER_
    raw-pressure >>= 4
    return raw-pressure

  pressure-raw-to-compensated_ raw/int temperature/float-> float:
    // Use the same names as in the formula in the datasheet.
    press-adc := raw
    t-fine := temperature * 5120.0
    par-p1 := calibration_.par-p1
    par-p2 := calibration_.par-p2
    par-p3 := calibration_.par-p3
    par-p4 := calibration_.par-p4
    par-p5 := calibration_.par-p5
    par-p6 := calibration_.par-p6
    par-p7 := calibration_.par-p7
    par-p8 := calibration_.par-p8
    par-p9 := calibration_.par-p9
    par-p10 := calibration_.par-p10

    // BME680, section 3.3.2.
    // BME688, section 3.6.2.
    var1 := ((t-fine / 2.0) - 64000.0)
    var2 := var1 * var1 * (par-p6 / 131072.0)
    var2 = var2 + (var1 * par-p5 * 2.0)
    var2 = (var2 / 4.0) + (par-p4 * 65536.0)
    var1 = (((par-p3 * var1 * var1) / 16384.0) +
         (par-p2 * var1)) / 524288.0
    var1 = (1.0 + (var1 / 32768.0)) * par-p1
    press-comp := 1048576.0 - press-adc
    press-comp = ((press-comp - (var2 / 4096.0)) * 6250.0) / var1
    var1 = (par-p9 * press-comp * press-comp) / 2147483648.0
    var2 = press-comp * (par-p8 / 32768.0)
    press-comp-div-256 := press-comp / 256.0
    var3 := press-comp-div-256 * press-comp-div-256 * press-comp-div-256 * (par-p10 / 131072.0)
    press-comp = press-comp + (var1 + var2 + var3 + (par-p7 * 128.0)) / 16.0

    return press-comp

  /**
  Reads the humidity and returns it in percent relative humidity.
  */
  read-humidity -> float:
    do-measurement_ --skip-gas
    return extract-humidity_

  extract-humidity_:
    temperature := extract-temperature_
    raw-humidity := extract-humidity_ --raw
    return humidity-raw-to-compensated_ raw-humidity temperature

  /**
  Reads the humidity and returns the raw ADC value.
  */
  read-humidity --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do-measurement_ --skip-gas
    return extract-humidity_ --raw

  extract-humidity_ --raw/bool -> int:
    raw-humidity := registers_.read-u16-be HUMIDITY-ADC-REGISTER_
    return raw-humidity

  humidity-raw-to-compensated_ raw/int temperature/float-> float:
    // Use the same names as in the formula in the datasheet.
    hum-adc := raw
    temp-comp := temperature
    par-h1 := calibration_.par-h1
    par-h2 := calibration_.par-h2
    par-h3 := calibration_.par-h3
    par-h4 := calibration_.par-h4
    par-h5 := calibration_.par-h5
    par-h6 := calibration_.par-h6
    par-h7 := calibration_.par-h7

    // BME680, section 3.3.3.
    // BME688, section 3.6.3.
    var1 := hum-adc - ((par-h1 * 16.0) + ((par-h3 / 2.0) * temp-comp))
    var2 := var1 * ((par-h2 / 262144.0) * (1.0 + ((par-h4 / 16384.0) *
         temp-comp) + ((par-h5 / 1048576.0) * temp-comp * temp-comp)))
    var3 := par-h6 / 16384.0
    var4 := par-h7 / 2097152.0
    hum-comp := var2 + ((var3 + (var4 * temp-comp)) * var2 * var2)
    return hum-comp

  /**
  Reads the gas resistance and returns it in Ohms.

  Note that the gas resistance measurement is unreliable for the first ~300 measurements. It's
    recommended to discard these measurements.
  */
  read-gas-resistance -> float:
    do-measurement_
    return extract-gas-resistance_

  extract-gas-resistance_:
    // We are not using $extract_gas_resistance_ --raw, as we also need the least significant
    // bits of the register. No need to do two register reads.
    register/int := ?
    if variant_ == BME680-VARIANT_:
      register = BME680-GAS-ADC-REGISTER_
    else if variant_ == BME688-VARIANT_:
      register = BME688-GAS-ADC-REGISTER_
    else:
      throw "UNKNOWN_VARIANT"

    gas-values := registers_.read-u16-be register
    adc := gas-values >> 6
    range := gas-values & 0x0F
    if (gas-values & GAS-VALID-MASK_) == 0: throw "GAS_NOT_VALID"
    if (gas-values & HEAT-STAB-MASK_) == 0: throw "HEATER_NOT_STABILIZED"
    return gas-adc-to-ohm_ adc range

  /**
  Reads the gas resistance and returns the raw ADC value.
  */
  read-gas-resistance --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do-measurement_
    return extract-gas-resistance_ --raw

  extract-gas-resistance_ --raw/bool -> int:
    register/int := ?
    if variant_ == BME680-VARIANT_:
      register = BME680-GAS-ADC-REGISTER_
    else if variant_ == BME688-VARIANT_:
      register = BME688-GAS-ADC-REGISTER_
    else:
      throw "UNKNOWN_VARIANT"

    raw-value := registers_.read-u16-be register
    if raw-value & GAS-VALID-MASK_ == 0: throw "GAS_NOT_VALID"
    if raw-value & HEAT-STAB-MASK_ == 0: throw "HEATER_NOT_STABILIZED"
    raw-value >>= 6
    return raw-value

  /** Converts the given gas ADC value to a resistance value. */
  gas-adc-to-ohm_ adc/int range/int-> float:
    if variant_ == BME680-VARIANT_:
      // BME680, section 3.4.1.
      var1 := (1340.0 + 5.0 * calibration_.range-switching-error) * CONST-ARRAY1_[range]
      gas-res := var1 * CONST-ARRAY2_[range] / (adc - 512.0 + var1)
      return gas-res

    if variant_ == BME688-VARIANT_:
      // BME680, section 3.7.1.
      var1 := 262144 >> range
      var2 := adc - 512
      var2 *= 3
      var2 += 4096

      calc-gas-res := 10000 * var1 / var2
      calc-gas-res *= 100
      return calc-gas-res.to-float
    else:
      throw "UNKNOWN_VARIANT"

  /**
  Triggers one measurement by putting the sensor into "force" mode.

  If $skip-gas is true, disables the gas measurement if it is activated.
  */
  do-measurement_ --skip-gas/bool=false:
    old-gas := is-gas-enabled_
    if skip-gas and old-gas:
      // It's not entirely clear if it makes a difference to disable the heater
      // when the gas measurement isn't activated.
      disable-gas_ --keep-heater

    try:
      // BME680, section 5.3.1.3
      // BME688, section 5.3.1.3
      MODE-FORCED ::= 1
      set-bits_ MODE-REGISTER_ MODE-MASK_ MODE-FORCED

      wait-for-measurement_ --wait-for-gas=(not skip-gas)

    finally:
      if skip-gas and old-gas: enable-gas_

  wait-for-measurement_ --wait-for-gas/bool:
    if wait-for-gas: sleep --ms=gas-wait-time-ms_
    // If maximum gas heater wait time is used (4096ms) it takes roughly
    // 90 iterations before the measurement is done.
    100.repeat:
      val := registers_.read-u8 MEAS-STATUS-REGISTER_
      if val & MEASURING-MASK_ == 0: return
      sleep --ms=it + 1  // Back off slowly.
    throw "BME68x: Unable to measure TPHG"


  /**
  The size of the Infinite Impulse Response filter.

  The IIR filter is a low-pass filter that is applied to the temperature and pressure readings (but not
    humidity and gas).

  The IIR filter formula is `x(n) = (x(n-1)*(c - 1) + new_val)/c` where `new_val` is the ADC's
    value, and `c` the filter coefficient, equal to $iir-filter-size + 1.

  The higher the value the slower the filter responds to changes.

  The returned value is one of:
  - $IIR-FILTER-SIZE-0
  - $IIR-FILTER-SIZE-1
  - $IIR-FILTER-SIZE-3
  - $IIR-FILTER-SIZE-7
  - $IIR-FILTER-SIZE-15
  - $IIR-FILTER-SIZE-31
  - $IIR-FILTER-SIZE-63
  - $IIR-FILTER-SIZE-127
  */
  iir-filter-size -> int:
    // BME680, section 5.3.2.4.
    // BME688, section
    encoded := get-bits_ IIR-FILTER-SIZE-REGISTER_ IIR-FILTER-SIZE-MASK_
    if encoded == 0: return IIR-FILTER-SIZE-0
    if encoded == 1: return IIR-FILTER-SIZE-1
    if encoded == 2: return IIR-FILTER-SIZE-3
    if encoded == 3: return IIR-FILTER-SIZE-7
    if encoded == 4: return IIR-FILTER-SIZE-15
    if encoded == 5: return IIR-FILTER-SIZE-31
    if encoded == 6: return IIR-FILTER-SIZE-63
    if encoded == 7: return IIR-FILTER-SIZE-127
    unreachable

  /**
  Sets the size of the IIR (infinite impulse response) filter.

  See $iir-filter-size for more information on the filter.

  If set to $IIR-FILTER-SIZE-0, then the filter is disabled.

  The parameter $new-val must be one of:
  - $IIR-FILTER-SIZE-0: Filter is disabled.
  - $IIR-FILTER-SIZE-1:
  - $IIR-FILTER-SIZE-3
  - $IIR-FILTER-SIZE-7
  - $IIR-FILTER-SIZE-15
  - $IIR-FILTER-SIZE-31
  - $IIR-FILTER-SIZE-63
  - $IIR-FILTER-SIZE-127
  */
  iir-filter-size= new-val/int:
    encoded := ?
    if new-val == IIR-FILTER-SIZE-0: encoded = 0
    else if new-val == IIR-FILTER-SIZE-1: encoded = 1
    else if new-val == IIR-FILTER-SIZE-3: encoded = 2
    else if new-val == IIR-FILTER-SIZE-7: encoded = 3
    else if new-val == IIR-FILTER-SIZE-15: encoded = 4
    else if new-val == IIR-FILTER-SIZE-31: encoded = 5
    else if new-val == IIR-FILTER-SIZE-63: encoded = 6
    else if new-val == IIR-FILTER-SIZE-127: encoded = 7
    else: throw "INVALID_VALUE"
    set-bits_ IIR-FILTER-SIZE-REGISTER_ IIR-FILTER-SIZE-MASK_ encoded

  /**
  The current humidity oversampling configuration.

  Returns one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  humidity-oversampling -> int:
    encoded := get-bits_ HUMIDITY-OVERSAMPLING-REGISTER_ HUMIDITY-OVERSAMPLING-MASK_
    return decode-oversampling_ encoded

  /**
  Sets the humidity oversampling to the given value.

  The parameter $new-val must be one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  humidity-oversampling= new-val/int:
    encoded := encode-oversampling_ new-val
    set-bits_ HUMIDITY-OVERSAMPLING-REGISTER_ HUMIDITY-OVERSAMPLING-MASK_ encoded

  /**
  The current temperature oversampling configuration.

  Returns one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  temperature-oversampling -> int:
    encoded := get-bits_ TEMPERATURE-OVERSAMPLING-REGISTER_ TEMPERATURE-OVERSAMPLING-MASK_
    return decode-oversampling_ encoded

  /**
  Sets the temperature oversampling to the given value.

  The parameter $new-val must be one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  temperature-oversampling= new-val/int:
    encoded := encode-oversampling_ new-val
    set-bits_ TEMPERATURE-OVERSAMPLING-REGISTER_ TEMPERATURE-OVERSAMPLING-MASK_ encoded

  /**
  The current pressure oversampling configuration.

  Returns one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  pressure-oversampling -> int:
    encoded := get-bits_ PRESSURE-OVERSAMPLING-REGISTER_ PRESSURE-OVERSAMPLING-MASK_
    return decode-oversampling_ encoded

  /**
  Sets the pressure oversampling to the given value.

  The parameter $new-val must be one of:
  - $OVERSAMPLING-X1
  - $OVERSAMPLING-X2
  - $OVERSAMPLING-X4
  - $OVERSAMPLING-X8
  - $OVERSAMPLING-X16
  */
  pressure-oversampling= new-val/int:
    encoded := encode-oversampling_ new-val
    set-bits_ PRESSURE-OVERSAMPLING-REGISTER_ PRESSURE-OVERSAMPLING-MASK_ encoded

  decode-oversampling_ encoded/int -> int:
    if encoded == 0: return 0
    if encoded == 1: return OVERSAMPLING-X1
    if encoded == 2: return OVERSAMPLING-X2
    if encoded == 3: return OVERSAMPLING-X4
    if encoded == 4: return OVERSAMPLING-X8
    return OVERSAMPLING-X16

  encode-oversampling_ val/int -> int:
    if val == OVERSAMPLING-X1: return 1
    if val == OVERSAMPLING-X2: return 2
    if val == OVERSAMPLING-X4: return 3
    if val == OVERSAMPLING-X8: return 4
    if val == OVERSAMPLING-X16: return 5
    throw "INVALID_ARGUMENT"

  /**
  Sets the gas heater configuration.
  Gas measurements are only enabled with a valid heater configuration.

  The $degrees parameter sets the temperature in Celsius the heater should be at. It must be
    in range the [0..400] degrees.
  The $ms parameter defines the time the heater should spend at that temperature before measuring. It
    must be in the range [0..4032].

  Typical values are ~320 degrees and ~150ms.

  If $degrees or $ms is 0, then the gas sensor is disabled.
  */
  set-gas-heater --degrees/int --ms/int:
    if not 0 <= degrees <= 400: throw "INVALID_ARGUMENT"
    if not 0 <= ms <= 4032: throw "INVALID_ARGUMENT"
    if degrees == 0 or ms == 0:
      gas-wait-time-ms_ = 0
      disable-gas_
      return

    gas-wait-time-ms_ = ms

    // Select heater set-point 0.
    // This should always be true, but let's be sure.
    set-bits_ GAS-SET-POINT-REGISTER_ GAS-SET-POINT-MASK_ 0

    // Configure set-point 0.
    heater-resistance := calculate-heater-resistance_ degrees
    registers_.write-u8 GAS-HEATER-RESISTANCE-REGISTER_ heater-resistance
    encoded-wait := calculate-wait-time_ ms
    registers_.write-u8 GAS-HEATER-WAIT-REGISTER_ encoded-wait
    enable-gas_

  /**
  Disables the gas measurement.
  Does not modify $gas-wait-time-ms_ and as such $is-gas-enabled_ still returns true,
    if $gas-wait-time-ms_ isn't modified otherwise.
  */
  disable-gas_ --keep-heater/bool=false:
    // Stop gas measurement.
    run-mask := ?
    if variant_ == BME680-VARIANT_:
      run-mask = BME680-RUN-GAS-MASK_
    else if variant_ == BME688-VARIANT_:
      run-mask = BME688-RUN-GAS-MASK_
    else:
      throw "UNKNOWN_VARIANT"
    set-bits_ GAS-RUN-GAS-REGISTER_ run-mask 0

    if keep-heater: return

    // Disable the heater.
    set-bits_ GAS-DISABLE-REGISTER_ GAS-DISABLE-MASK_ 1

  enable-gas_:
    // Clear the disable-heater bit.
    set-bits_ GAS-DISABLE-REGISTER_ GAS-DISABLE-MASK_ 0

    // And start gas measurement.
    run-mask := ?
    if variant_ == BME680-VARIANT_:
      run-mask = BME680-RUN-GAS-MASK_
    else if variant_ == BME688-VARIANT_:
      run-mask = BME688-RUN-GAS-MASK_
    else:
      throw "UNKNOWN_VARIANT"
    set-bits_ GAS-RUN-GAS-REGISTER_ run-mask 1

  /**
  Whether the gas measurement is enabled.
  This function is internal and used to temporarily disable the gas measurement when the user only
    asks for temperature, pressure or humidity.
  */
  is-gas-enabled_ -> bool:
    return gas-wait-time-ms_ != 0

  /**
  Computes the heater resistance for the given $degrees.

  The resistance is dependent on the ambient temperature.
  */
  calculate-heater-resistance_ degrees/int -> int:
    // TODO(florian): measure the current ambient temperature.
    amb-temp := 25
    target-temp := degrees

    res-heat-range := calibration_.res-heat-range
    res-heat-val := calibration_.res-heat-val

    // BME680, section 3.3.5
    // BME688, section 3.6.5
    var1 := (calibration_.par-g1 / 16.0) + 49.0
    var2 := ((calibration_.par-g2 / 32768.0) * 0.0005) + 0.00235
    var3 := calibration_.par-g3 / 1024.0
    var4 := var1 * (1.0 + (var2 * target-temp))
    var5 := var4 + (var3 * amb-temp)
    res-heat := 3.4 * ((var5 * (4.0 / (4.0 + res-heat-range)) * (1.0 / (1.0 + (res-heat-val * 0.002)))) - 25)

    return res-heat.to-int

  /**
  Computes the encoded value for the sensor to wait the given $ms when doing the gas measurement.
  */
  calculate-wait-time_ ms/int -> int:
    // BME680, section 5.3.3.3
    // BME688, section 5.3.4.3
    // The wait time is encoded into 8 bits.
    // The first most significant 2 bits specify the multiplication factor:
    // 01 -> 1; 10 -> 4; 10 -> 16; 11 -> 64.
    // Basically, each increase in the factor bits increases the remaining bits by a factor of 4.
    factor := 0
    while ms > 0x3F:
      ms >>= 2
      factor++
    return (factor << 6) | ms

  read-calibration_ -> Calibration_:
    calibration := Calibration_

    // Read temperature calibration.
    calibration.par-t1 = registers_.read-u16-le PAR-T1-REGISTER_
    calibration.par-t2 = registers_.read-i16-le PAR-T2-REGISTER_
    calibration.par-t3 = registers_.read-i8 PAR-T3-REGISTER_

    // Read pressure calibration.
    calibration.par-p1  = registers_.read-u16-le  PAR-P1-REGISTER_
    calibration.par-p2  = registers_.read-i16-le  PAR-P2-REGISTER_
    calibration.par-p3  = registers_.read-i8      PAR-P3-REGISTER_
    calibration.par-p4  = registers_.read-i16-le  PAR-P4-REGISTER_
    calibration.par-p5  = registers_.read-i16-le  PAR-P5-REGISTER_
    calibration.par-p6  = registers_.read-i8      PAR-P6-REGISTER_
    calibration.par-p7  = registers_.read-i8      PAR-P7-REGISTER_
    calibration.par-p8  = registers_.read-i16-le  PAR-P8-REGISTER_
    calibration.par-p9  = registers_.read-i16-le  PAR-P9-REGISTER_
    calibration.par-p10 = registers_.read-i8      PAR-P10-REGISTER_

    // Read humidity calibration.
    par-h1 := (registers_.read-u8  PAR-H1-MSB-REGISTER_) << 4
    par-h1 |= (registers_.read-u8 PAR-H1-LSB-REGISTER_) & 0x0F
    calibration.par-h1 = par-h1
    par-h2 := (registers_.read-u8  PAR-H2-MSB-REGISTER_) << 4
    par-h2 |= (registers_.read-u8 PAR-H2-LSB-REGISTER_) >> 4
    calibration.par-h2 = par-h2
    calibration.par-h3 = registers_.read-i8 PAR-H3-REGISTER_
    calibration.par-h4 = registers_.read-i8 PAR-H4-REGISTER_
    calibration.par-h5 = registers_.read-i8 PAR-H5-REGISTER_
    calibration.par-h6 = registers_.read-i8 PAR-H6-REGISTER_
    calibration.par-h7 = registers_.read-i8 PAR-H7-REGISTER_

    // Read gas calibration.
    calibration.par-g1 = registers_.read-i8     PAR-G1-REGISTER_
    calibration.par-g2 = registers_.read-i16-le PAR-G2-REGISTER_
    calibration.par-g3 = registers_.read-i8     PAR-G3-REGISTER_

    // Heater range calculation.
    calibration.res-heat-range = ((registers_.read-u8 RES-HEAT-RANGE-REGISTER_) >> 4) & 0b11

    // Resistance correction factor.
    calibration.res-heat-val = registers_.read-i8 RES-HEAT-VAL-REGISTER_

    // Range switching error.
    if variant_ == BME680-VARIANT_:
      calibration.range-switching-error = (registers_.read-i8 BME680-RANGE-SWITCHING-ERROR-REGISTER_) >> 4
    else if variant_ == BME688-VARIANT_:
      // Do nothing.
    else:
      throw "UNKNOWN_VARIANT"

    return calibration

  /**
  Updates the $register value by replacing the bits selected by the given $mask with the new $value.

  First reads the old value, then clears the old bits, then shifts the new $value into place, and finally
    writes the combined value back to the $register.
  */
  set-bits_ register/int mask/int value/int -> none:
    old := registers_.read-u8 register
    cleared := old & ~mask
    shifted := value
    shifted-mask := 0x01
    while shifted-mask & mask == 0:
      shifted <<= 1
      shifted-mask <<= 1
    shifted &= mask
    registers_.write-u8 register (cleared | shifted)

  /**
  Reads the bits corresponding to the given $mask in the given $register.
  */
  get-bits_ register/int mask/int -> int:
    val := registers_.read-u8 register
    while mask & 0x01 == 0:
      val >>= 1
      mask >>= 1
    return val & mask

/** Calibration coefficients provided by the sensor. */
class Calibration_:
  // Temperature related coefficients.
  par-t1/int := 0
  par-t2/int := 0
  par-t3/int := 0

  // Pressure related coefficients.
  par-p1/int  := 0
  par-p2/int  := 0
  par-p3/int  := 0
  par-p4/int  := 0
  par-p5/int  := 0
  par-p6/int  := 0
  par-p7/int  := 0
  par-p8/int  := 0
  par-p9/int  := 0
  par-p10/int := 0

  // Humidity related coefficients.
  par-h1/int := 0
  par-h2/int := 0
  par-h3/int := 0
  par-h4/int := 0
  par-h5/int := 0
  par-h6/int := 0
  par-h7/int := 0

  // Gas related coefficients.
  par-g1/int := 0
  par-g2/int := 0
  par-g3/int := 0

  res-heat-range/int := 0
  res-heat-val/int   := 0
  range-switching-error/int := 0
