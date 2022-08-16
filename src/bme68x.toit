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
Use $Bme68x.read_temperature, $Bme68x.read_pressure, $Bme68x.read_humidity,
  $Bme68x.read_gas_resistance to read individual measurements.
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
  gas_resistance/float?

  constructor --.temperature --.pressure --.humidity --.gas_resistance:

  stringify -> string:
    str := "$(%.3f temperature)°C, $(%.3f pressure)Pa, $(%.3f humidity)%"
    if gas_resistance: str += ", $gas_resistance Ohm"
    return str

/**
A driver for the BME680 and BME688 sensors.
*/
class Bme68x:
  static I2C_ADDRESS     ::= 0x76
  static I2C_ADDRESS_ALT ::= 0x77

  static BME680_VARIANT_ ::= 0
  static BME688_VARIANT_ ::= 1

  /** Disables the IIR filter. */
  static IIR_FILTER_SIZE_0   ::= 0
  /** An IIR filter coefficient of 1 */
  static IIR_FILTER_SIZE_1   ::= 1
  /** An IIR filter coefficient of 3 */
  static IIR_FILTER_SIZE_3   ::= 3
  /** An IIR filter coefficient of 7 */
  static IIR_FILTER_SIZE_7   ::= 7
  /** An IIR filter coefficient of 15 */
  static IIR_FILTER_SIZE_15  ::= 15
  /** An IIR filter coefficient of 31 */
  static IIR_FILTER_SIZE_31  ::= 31
  /** An IIR filter coefficient of 63 */
  static IIR_FILTER_SIZE_63  ::= 63
  /** An IIR filter coefficient of 127 */
  static IIR_FILTER_SIZE_127 ::= 127

  /** Oversampling by a factor of 1x. */
  static OVERSAMPLING_X1   ::= 1
  /** Oversampling by a factor of 2x. */
  static OVERSAMPLING_X2   ::= 2
  /** Oversampling by a factor of 4x. */
  static OVERSAMPLING_X4   ::= 4
  /** Oversampling by a factor of 8x. */
  static OVERSAMPLING_X8   ::= 8
  /** Oversampling by a factor of 16x. */
  static OVERSAMPLING_X16  ::= 16

  static CTRL_MEAS_REGISTER_ ::= 0x74
  // Gives the variant ID of this chip.
  // The BME680 doesn't have this register.
  static VARIANT_ID_REGISTER_ ::= 0xF0

  // Bme680, section 5.3.2.4
  // Bme688, section 5.3.3.4
  static IIR_FILTER_SIZE_REGISTER_ ::= 0x75
  static IIR_FILTER_SIZE_MASK_ ::= 0x1C

  // Bme680, section 5.3.2.1
  // Bme688, section 5.3.3.1
  static HUMIDITY_OVERSAMPLING_REGISTER_ ::= 0x72
  static HUMIDITY_OVERSAMPLING_MASK_ ::= 0x07

  // Bme680, section 5.3.2.2
  // Bme688, section 5.3.3.2
  static TEMPERATURE_OVERSAMPLING_REGISTER_ ::= 0x74
  static TEMPERATURE_OVERSAMPLING_MASK_ ::= 0x70

  // Bme680, section 5.3.2.3
  // Bme688, section 5.3.3.3
  static PRESSURE_OVERSAMPLING_REGISTER_ ::= 0x74
  static PRESSURE_OVERSAMPLING_MASK_ ::= 0x1C

  // Temperature registers.
  // Bme680, section 3.3.1, table 11.
  // Bme688, section 3.6.1, table 13
  static TEMPERATURE_ADC_REGISTER_ ::= 0x22 // 20 bits. (Reg_0x24 & 0xF0)=LSB.
  // Calibration:
  static PAR_T1_REGISTER_ ::=  0xE9  // 16 bits. 0xEA=MSB.
  static PAR_T2_REGISTER_ ::=  0x8A  // 16 bits. 0x8B=MSB.
  static PAR_T3_REGISTER_ ::=  0x8C  // 8 bits.

  // Pressure registers.
  // BME680, section 3.3.2, table 12.
  // BME688, section 3.6.2, table 14
  static PRESSURE_ADC_REGISTER_ ::= 0x1F // 20 bits. (Reg_0x21 & 0xF0)=LSB
  // Calibration:
  static PAR_P1_REGISTER_ ::=  0x8E  // 16 bits. 0x8F=MSB.
  static PAR_P2_REGISTER_ ::=  0x90  // 16 bits. 0x91=MSB.
  static PAR_P3_REGISTER_ ::=  0x92  // 8 bits.
  static PAR_P4_REGISTER_ ::=  0x94  // 16 bits. 0x95=MSB.
  static PAR_P5_REGISTER_ ::=  0x96  // 16 bits. 0x97=MSB.
  static PAR_P6_REGISTER_ ::=  0x99  // 8 bits.
  static PAR_P7_REGISTER_ ::=  0x98  // 8 bits.
  static PAR_P8_REGISTER_ ::=  0x9C  // 16 bits. 0x9D=MSB.
  static PAR_P9_REGISTER_ ::=  0x9E  // 16 bits. 0x9F=MSB.
  static PAR_P10_REGISTER_ ::= 0xA0  // 8 bits.

  // Humidity registers.
  // BME680, section 3.3.3, table 13.
  // BME688, section 3.6.3, table 15
  static HUMIDITY_ADC_REGISTER_ ::= 0x25 // 16 bits. 0x26=LSB.
  // Calibration:
  static PAR_H1_LSB_REGISTER_ ::= 0xE2  // Shared with PAR_H2_LSB_REGISTER_. Lower nibble.
  static PAR_H1_MSB_REGISTER_ ::= 0xE3
  static PAR_H2_LSB_REGISTER_ ::= 0xE2  // Shared with PAR_H1_LSB_REGISTER_. Higher nibble.
  static PAR_H2_MSB_REGISTER_ ::= 0xE1
  static PAR_H3_REGISTER_ ::= 0xE4
  static PAR_H4_REGISTER_ ::= 0xE5
  static PAR_H5_REGISTER_ ::= 0xE6
  static PAR_H6_REGISTER_ ::= 0xE7
  static PAR_H7_REGISTER_ ::= 0xE8

  // Gas registers.
  // BME680, section 3.4.1, table 15.
  static BME680_GAS_ADC_REGISTER_ ::= 0x2A // 10 bits. 0x2A=MSB. (Reg_0x2B & 0xC0)=LSB, shared with range.
  static BME680_GAS_RANGE_REGISTER_ ::= 0x2B // Shared with ADC. Lower nibble.
  // BME688, section 3.6.5, table 16, 3.7.1, table 17
  static BME688_GAS_ADC_REGISTER_ ::= 0x2C // 10 bits. 0x2C=MSB. (Reg_0x2D & 0xC0)=LSB, shared with range.
  static BME688_GAS_RANGE_REGISTER_ ::= 0x2D // Shared with ADC. Lower nibble.
  // Same for BME680 and BME688.
  // Calibration:
  static PAR_G1_REGISTER_ ::= 0xED // 8 bits.
  static PAR_G2_REGISTER_ ::= 0xEB // 16 bits. 0xEC=MSB.
  static PAR_G3_REGISTER_ ::= 0xEE // 8 bits.
  // According to datasheet
  static RES_HEAT_VAL_REGISTER_ ::= 0x00    // 8 bits.
  static RES_HEAT_RANGE_REGISTER_ ::= 0x02  // Mask 0x30.
  // BME680, section 3.4.1.
  static BME680_RANGE_SWITCHING_ERROR_REGISTER_ ::= 0x04  // Signed. 4 bit with mask 0xF0.
  // BME680, BME688, section 5.2
  static GAS_DISABLE_REGISTER_ ::= 0x70
  static GAS_DISABLE_MASK_ ::= 0x08
  static GAS_RUN_GAS_REGISTER_ ::= 0x71
  static BME680_RUN_GAS_MASK_ ::= 0x10
  static BME688_RUN_GAS_MASK_ ::= 0x20
  static GAS_VALID_MASK_ ::= 0x20
  static HEAT_STAB_MASK_ ::= 0x10
  // Registers of the first gas sensor heater set-point.
  // Resistance register of the first set-point.
  static GAS_HEATER_RESISTANCE_REGISTER_ ::= 0x5A
  // Wait register of the first set-point.
  static GAS_HEATER_WAIT_REGISTER_ ::= 0x64

  static GAS_SET_POINT_REGISTER_ ::= 0x71
  static GAS_SET_POINT_MASK_ ::= 0x0F

  static MODE_REGISTER_ ::= CTRL_MEAS_REGISTER_
  static MODE_MASK_ ::= 0x03

  // The status register indicating whether a measurement is in progress or new data is available.
  static MEAS_STATUS_REGISTER_ ::= 0x1D
  static NEW_DATA_MASK_ ::= 0x80
  static MEASURING_MASK_ ::= 0x60

  // ADC Ranges used for gas resistance calculations.
  // Section 3.4.1, table 16.
  static CONST_ARRAY1_ ::= [1.0, 1.0, 1.0, 1.0, 1.0, 0.99, 1.0, 0.992,
                            1.0, 1.0, 0.998, 0.995, 1.0, 0.99, 1.0, 1.0]
  static CONST_ARRAY2_ ::= [8000000.0, 4000000.0, 2000000.0, 1000000.0,
                            499500.4995, 248262.1648, 125000.0, 63004.03226,
                            31281.28128, 15625.0, 7812.5, 3906.25,
                            1953.125, 976.5625, 488.28125, 244.140625]

  registers_/serial.Registers ::= ?

  variant_/int := -1
  calibration_/Calibration_? := null

  /**
  The time the gas measurement should wait for. We use this to not poll the sensor too eagerly.
  */
  gas_wait_time_ms_/int := 0
  /** The gas_range that is currently configured. Needed to convert the ADC value to Ohms. */
  gas_range_/int := 0

  constructor dev/serial.Device:
    registers_ = dev.registers

  /**
  Initializes the sensor.

  See $Bme68x.iir_filter_size for information on $iir_filter_size.
  See $Bme68x.humidity_oversampling for information on $humidity_oversampling.
  See $Bme68x.temperature_oversampling for information on $temperature_oversampling.
  See $Bme68x.pressure_oversampling for information on $pressure_oversampling.
  See $set_gas_heater for information on $gas_degrees and $gas_ms.
  */
  on -> none
      --iir_filter_size/int=IIR_FILTER_SIZE_3
      --humidity_oversampling/int=OVERSAMPLING_X2
      --pressure_oversampling/int=OVERSAMPLING_X4
      --temperature_oversampling/int=OVERSAMPLING_X8
      --gas_degrees/int=320 --gas_ms/int=150:
    if variant_ != -1: throw "ALREADY_ON"

    variant_ = BME680_VARIANT_
    catch:
      variant := registers_.read_u8 VARIANT_ID_REGISTER_
      if variant != 0 and variant != 1: throw "Unknown BME68x variant"
      variant_ = variant

    calibration_ = read_calibration_

    // Do a default configuration.
    this.iir_filter_size = iir_filter_size
    this.humidity_oversampling = humidity_oversampling
    this.temperature_oversampling = temperature_oversampling
    this.pressure_oversampling = pressure_oversampling
    set_gas_heater --degrees=gas_degrees --ms=gas_ms
    // Sleep to give the gas heater time to reach the set-point.
    if gas_degrees != 0 and gas_ms != 0: sleep --ms=500

  off:
    // Make sure the device is in idle mode and disable the gas heater.
    disable_gas_
    set_bits_ MODE_REGISTER_ MODE_MASK_ 0x00
    variant_ = -1

  /**
  Takes one measurement and returns the result.
  */
  read -> Measurement:
    do_measurement_
    temperature := extract_temperature_
    raw_pressure := extract_pressure_ --raw
    pressure := pressure_raw_to_compensated_ raw_pressure temperature
    raw_humidity := extract_humidity_ --raw
    humidity := humidity_raw_to_compensated_ raw_humidity temperature
    gas_resistance := is_gas_enabled_ ? extract_gas_resistance_ : null
    return Measurement
        --temperature=temperature
        --pressure=pressure
        --humidity=humidity
        --gas_resistance=gas_resistance

  /**
  Reads the temperature and returns it in degrees Celsius.
  */
  read_temperature -> float:
    do_measurement_ --skip_gas
    return extract_temperature_

  extract_temperature_:
    raw := extract_temperature_ --raw
    return temperature_raw_to_compensated_ raw

  /**
  Reads the temperature and returns the raw ADC value.
  */
  read_temperature --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do_measurement_ --skip_gas
    return extract_temperature_ --raw

  extract_temperature_ --raw/bool -> int:
    // BME680, section 5.3.4.2
    // BME688, section 5.3.5.2
    raw_value := registers_.read_u24_be TEMPERATURE_ADC_REGISTER_
    raw_value >>= 4
    // Note that the least-significant 4 bits are only meaningful if oversampling is enabled.
    return raw_value

  /**
  Converts the temperature ADC value to a compensated temperature value.
  */
  temperature_raw_to_compensated_ raw/int -> float:
    // Use the same names as in the formula in the datasheet.
    temp_adc := raw
    par_t1 := calibration_.par_t1
    par_t2 := calibration_.par_t2
    par_t3 := calibration_.par_t3

    // BME680, section 3.3.1.
    // BME688, section 3.6.1.
    var1 := (temp_adc / 16384.0 - par_t1 / 1024.0) * par_t2
    temp_adc_div_131073 := temp_adc / 131072.0
    par_t1_div_8192 := par_t1 / 8192.0
    var2 := temp_adc_div_131073 - par_t1_div_8192
    var2 *= var2
    var2 *= par_t3 * 16.0
    t_fine := var1 + var2
    return t_fine / 5120.0

  /**
  Reads the barometric pressure and returns it in Pascals.
  */
  read_pressure -> float:
    do_measurement_ --skip_gas
    return extract_pressure_

  extract_pressure_:
    temperature := extract_temperature_
    raw_pressure := extract_pressure_ --raw
    return pressure_raw_to_compensated_ raw_pressure temperature

  /**
  Reads the barometric pressure and returns the raw sensor value.
  */
  read_pressure --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do_measurement_ --skip_gas
    return extract_pressure_ --raw

  extract_pressure_ --raw/bool -> int:
    raw_pressure := registers_.read_u24_be PRESSURE_ADC_REGISTER_
    raw_pressure >>= 4
    return raw_pressure

  pressure_raw_to_compensated_ raw/int temperature/float-> float:
    // Use the same names as in the formula in the datasheet.
    press_adc := raw
    t_fine := temperature * 5120.0
    par_p1 := calibration_.par_p1
    par_p2 := calibration_.par_p2
    par_p3 := calibration_.par_p3
    par_p4 := calibration_.par_p4
    par_p5 := calibration_.par_p5
    par_p6 := calibration_.par_p6
    par_p7 := calibration_.par_p7
    par_p8 := calibration_.par_p8
    par_p9 := calibration_.par_p9
    par_p10 := calibration_.par_p10

    // BME680, section 3.3.2.
    // BME688, section 3.6.2.
    var1 := ((t_fine / 2.0) - 64000.0)
    var2 := var1 * var1 * (par_p6 / 131072.0)
    var2 = var2 + (var1 * par_p5 * 2.0)
    var2 = (var2 / 4.0) + (par_p4 * 65536.0)
    var1 = (((par_p3 * var1 * var1) / 16384.0) +
         (par_p2 * var1)) / 524288.0
    var1 = (1.0 + (var1 / 32768.0)) * par_p1
    press_comp := 1048576.0 - press_adc
    press_comp = ((press_comp - (var2 / 4096.0)) * 6250.0) / var1
    var1 = (par_p9 * press_comp * press_comp) / 2147483648.0
    var2 = press_comp * (par_p8 / 32768.0)
    press_comp_div_256 := press_comp / 256.0
    var3 := press_comp_div_256 * press_comp_div_256 * press_comp_div_256 * (par_p10 / 131072.0)
    press_comp = press_comp + (var1 + var2 + var3 + (par_p7 * 128.0)) / 16.0

    return press_comp

  /**
  Reads the humidity and returns it in percent relative humidity.
  */
  read_humidity -> float:
    do_measurement_ --skip_gas
    return extract_humidity_

  extract_humidity_:
    temperature := extract_temperature_
    raw_humidity := extract_humidity_ --raw
    return humidity_raw_to_compensated_ raw_humidity temperature

  /**
  Reads the humidity and returns the raw ADC value.
  */
  read_humidity --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do_measurement_ --skip_gas
    return extract_humidity_ --raw

  extract_humidity_ --raw/bool -> int:
    raw_humidity := registers_.read_u16_be HUMIDITY_ADC_REGISTER_
    return raw_humidity

  humidity_raw_to_compensated_ raw/int temperature/float-> float:
    // Use the same names as in the formula in the datasheet.
    hum_adc := raw
    temp_comp := temperature
    par_h1 := calibration_.par_h1
    par_h2 := calibration_.par_h2
    par_h3 := calibration_.par_h3
    par_h4 := calibration_.par_h4
    par_h5 := calibration_.par_h5
    par_h6 := calibration_.par_h6
    par_h7 := calibration_.par_h7

    // BME680, section 3.3.3.
    // BME688, section 3.6.3.
    var1 := hum_adc - ((par_h1 * 16.0) + ((par_h3 / 2.0) * temp_comp))
    var2 := var1 * ((par_h2 / 262144.0) * (1.0 + ((par_h4 / 16384.0) *
         temp_comp) + ((par_h5 / 1048576.0) * temp_comp * temp_comp)))
    var3 := par_h6 / 16384.0
    var4 := par_h7 / 2097152.0
    hum_comp := var2 + ((var3 + (var4 * temp_comp)) * var2 * var2)
    return hum_comp

  /**
  Reads the gas resistance and returns it in Ohms.

  Note that the gas resistance measurement is unreliable for the first ~300 measurements. It's
    recommended to discard these measurements.
  */
  read_gas_resistance -> float:
    do_measurement_
    return extract_gas_resistance_

  extract_gas_resistance_:
    // We are not using $extract_gas_resistance_ --raw, as we also need the least significant
    // bits of the register. No need to do two register reads.
    register/int := ?
    if variant_ == BME680_VARIANT_:
      register = BME680_GAS_ADC_REGISTER_
    else if variant_ == BME688_VARIANT_:
      register = BME680_GAS_ADC_REGISTER_
    else:
      throw "UNKNOWN_VARIANT"

    gas_values := registers_.read_u16_be register
    adc := gas_values >> 6
    range := gas_values & 0x0F
    if (gas_values & GAS_VALID_MASK_) == 0: throw "GAS_NOT_VALID"
    if (gas_values & HEAT_STAB_MASK_) == 0: throw "HEATER_NOT_STABILIZED"
    return gas_adc_to_ohm_ adc range

  /**
  Reads the gas resistance and returns the raw ADC value.
  */
  read_gas_resistance --raw/bool -> int:
    if not raw: throw "INVALID_ARGUMENT"
    do_measurement_
    return extract_gas_resistance_ --raw

  extract_gas_resistance_ --raw/bool -> int:
    register/int := ?
    if variant_ == BME680_VARIANT_:
      register = BME680_GAS_ADC_REGISTER_
    else if variant_ == BME688_VARIANT_:
      register = BME680_GAS_ADC_REGISTER_
    else:
      throw "UNKNOWN_VARIANT"

    raw_value := registers_.read_u16_be register
    if raw_value & GAS_VALID_MASK_ == 0: throw "GAS_NOT_VALID"
    if raw_value & HEAT_STAB_MASK_ == 0: throw "HEATER_NOT_STABILIZED"
    raw_value >>= 6
    return raw_value

  /** Converts the given gas ADC value to a resistance value. */
  gas_adc_to_ohm_ adc/int range/int-> float:
    if variant_ == BME680_VARIANT_:
      // BME680, section 3.4.1.
      var1 := (1340.0 + 5.0 * calibration_.range_switching_error) * CONST_ARRAY1_[range]
      gas_res := var1 * CONST_ARRAY2_[range] / (adc - 512.0 + var1)
      return gas_res

    if variant_ == BME688_VARIANT_:
      // BME680, section 3.7.1.
      var1 := 262144 >> range
      var2 := adc - 512
      var2 *= 3
      var2 += 4096

      calc_gas_res := 10000 * var1 / var2
      calc_gas_res *= 100
      return calc_gas_res.to_float
    else:
      throw "UNKNOWN_VARIANT"

  /**
  Triggers one measurement by putting the sensor into "force" mode.

  If $skip_gas is true, disables the gas measurement if it is activated.
  */
  do_measurement_ --skip_gas/bool=false:
    old_gas := is_gas_enabled_
    if skip_gas and old_gas:
      // It's not entirely clear if it makes a difference to disable the heater
      // when the gas measurement isn't activated.
      disable_gas_ --keep_heater

    try:
      // BME680, section 5.3.1.3
      // BME688, section 5.3.1.3
      MODE_FORCED ::= 1
      set_bits_ MODE_REGISTER_ MODE_MASK_ MODE_FORCED

      wait_for_measurement_ --wait_for_gas=(not skip_gas)

    finally:
      if skip_gas and old_gas: enable_gas_

  wait_for_measurement_ --wait_for_gas/bool:
    if wait_for_gas: sleep --ms=gas_wait_time_ms_
    // If maximum gas heater wait time is used (4096ms) it takes roughly
    // 90 iterations before the measurement is done.
    100.repeat:
      val := registers_.read_u8 MEAS_STATUS_REGISTER_
      if val & MEASURING_MASK_ == 0: return
      sleep --ms=it + 1  // Back off slowly.
    throw "BME68x: Unable to measure TPHG"


  /**
  The size of the Infinite Impulse Response filter.

  The IIR filter is a low-pass filter that is applied to the temperature and pressure readings (but not
    humidity and gas).

  The IIR filter formula is `x(n) = (x(n-1)*(c - 1) + new_val)/c` where `new_val` is the ADC's
    value, and `c` the filter coefficient, equal to $iir_filter_size + 1.

  The higher the value the slower the filter responds to changes.

  The returned value is one of:
  - $IIR_FILTER_SIZE_0
  - $IIR_FILTER_SIZE_1
  - $IIR_FILTER_SIZE_3
  - $IIR_FILTER_SIZE_7
  - $IIR_FILTER_SIZE_15
  - $IIR_FILTER_SIZE_31
  - $IIR_FILTER_SIZE_63
  - $IIR_FILTER_SIZE_127
  */
  iir_filter_size -> int:
    // BME680, section 5.3.2.4.
    // BME688, section
    encoded := get_bits_ IIR_FILTER_SIZE_REGISTER_ IIR_FILTER_SIZE_MASK_
    if encoded == 0: return IIR_FILTER_SIZE_0
    if encoded == 1: return IIR_FILTER_SIZE_1
    if encoded == 2: return IIR_FILTER_SIZE_3
    if encoded == 3: return IIR_FILTER_SIZE_7
    if encoded == 4: return IIR_FILTER_SIZE_15
    if encoded == 5: return IIR_FILTER_SIZE_31
    if encoded == 6: return IIR_FILTER_SIZE_63
    if encoded == 7: return IIR_FILTER_SIZE_127
    unreachable

  /**
  Sets the size of the IIR (infinite impulse response) filter.

  See $iir_filter_size for more information on the filter.

  If set to $IIR_FILTER_SIZE_0, then the filter is disabled.

  The parameter $new_val must be one of:
  - $IIR_FILTER_SIZE_0: Filter is disabled.
  - $IIR_FILTER_SIZE_1:
  - $IIR_FILTER_SIZE_3
  - $IIR_FILTER_SIZE_7
  - $IIR_FILTER_SIZE_15
  - $IIR_FILTER_SIZE_31
  - $IIR_FILTER_SIZE_63
  - $IIR_FILTER_SIZE_127
  */
  iir_filter_size= new_val/int:
    encoded := ?
    if new_val == IIR_FILTER_SIZE_0: encoded = 0
    else if new_val == IIR_FILTER_SIZE_1: encoded = 1
    else if new_val == IIR_FILTER_SIZE_3: encoded = 2
    else if new_val == IIR_FILTER_SIZE_7: encoded = 3
    else if new_val == IIR_FILTER_SIZE_15: encoded = 4
    else if new_val == IIR_FILTER_SIZE_31: encoded = 5
    else if new_val == IIR_FILTER_SIZE_63: encoded = 6
    else if new_val == IIR_FILTER_SIZE_127: encoded = 7
    else: throw "INVALID_VALUE"
    set_bits_ IIR_FILTER_SIZE_REGISTER_ IIR_FILTER_SIZE_MASK_ encoded

  /**
  The current humidity oversampling configuration.

  Returns one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  humidity_oversampling -> int:
    encoded := get_bits_ HUMIDITY_OVERSAMPLING_REGISTER_ HUMIDITY_OVERSAMPLING_MASK_
    return decode_oversampling_ encoded

  /**
  Sets the humidity oversampling to the given value.

  The parameter $new_val must be one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  humidity_oversampling= new_val/int:
    encoded := encode_oversampling_ new_val
    set_bits_ HUMIDITY_OVERSAMPLING_REGISTER_ HUMIDITY_OVERSAMPLING_MASK_ encoded

  /**
  The current temperature oversampling configuration.

  Returns one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  temperature_oversampling -> int:
    encoded := get_bits_ TEMPERATURE_OVERSAMPLING_REGISTER_ TEMPERATURE_OVERSAMPLING_MASK_
    return decode_oversampling_ encoded

  /**
  Sets the temperature oversampling to the given value.

  The parameter $new_val must be one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  temperature_oversampling= new_val/int:
    encoded := encode_oversampling_ new_val
    set_bits_ TEMPERATURE_OVERSAMPLING_REGISTER_ TEMPERATURE_OVERSAMPLING_MASK_ encoded

  /**
  The current pressure oversampling configuration.

  Returns one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  pressure_oversampling -> int:
    encoded := get_bits_ PRESSURE_OVERSAMPLING_REGISTER_ PRESSURE_OVERSAMPLING_MASK_
    return decode_oversampling_ encoded

  /**
  Sets the pressure oversampling to the given value.

  The parameter $new_val must be one of:
  - $OVERSAMPLING_X1
  - $OVERSAMPLING_X2
  - $OVERSAMPLING_X4
  - $OVERSAMPLING_X8
  - $OVERSAMPLING_X16
  */
  pressure_oversampling= new_val/int:
    encoded := encode_oversampling_ new_val
    set_bits_ PRESSURE_OVERSAMPLING_REGISTER_ PRESSURE_OVERSAMPLING_MASK_ encoded

  decode_oversampling_ encoded/int -> int:
    if encoded == 0: return 0
    if encoded == 1: return OVERSAMPLING_X1
    if encoded == 2: return OVERSAMPLING_X2
    if encoded == 3: return OVERSAMPLING_X4
    if encoded == 4: return OVERSAMPLING_X8
    return OVERSAMPLING_X16

  encode_oversampling_ val/int -> int:
    if val == OVERSAMPLING_X1: return 1
    if val == OVERSAMPLING_X2: return 2
    if val == OVERSAMPLING_X4: return 3
    if val == OVERSAMPLING_X8: return 4
    if val == OVERSAMPLING_X16: return 5
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
  set_gas_heater --degrees/int --ms/int:
    if not 0 <= degrees <= 400: throw "INVALID_ARGUMENT"
    if not 0 <= ms <= 4032: throw "INVALID_ARGUMENT"
    if degrees == 0 or ms == 0:
      gas_wait_time_ms_ = 0
      disable_gas_
      return

    gas_wait_time_ms_ = ms

    // Select heater set-point 0.
    // This should always be true, but let's be sure.
    set_bits_ GAS_SET_POINT_REGISTER_ GAS_SET_POINT_MASK_ 0

    // Configure set-point 0.
    heater_resistance := calculate_heater_resistance_ degrees
    registers_.write_u8 GAS_HEATER_RESISTANCE_REGISTER_ heater_resistance
    encoded_wait := calculate_wait_time_ ms
    registers_.write_u8 GAS_HEATER_WAIT_REGISTER_ encoded_wait
    enable_gas_

  /**
  Disables the gas measurement.
  Does not modify $gas_wait_time_ms_ and as such $is_gas_enabled_ still returns true,
    if $gas_wait_time_ms_ isn't modified otherwise.
  */
  disable_gas_ --keep_heater/bool=false:
    // Stop gas measurement.
    run_mask := ?
    if variant_ == BME680_VARIANT_:
      run_mask = BME680_RUN_GAS_MASK_
    else if variant_ == BME688_VARIANT_:
      run_mask = BME688_RUN_GAS_MASK_
    else:
      throw "UNKNOWN_VARIANT"
    set_bits_ GAS_RUN_GAS_REGISTER_ run_mask 0

    if keep_heater: return

    // Disable the heater.
    set_bits_ GAS_DISABLE_REGISTER_ GAS_DISABLE_MASK_ 1

  enable_gas_:
    // Clear the disable-heater bit.
    set_bits_ GAS_DISABLE_REGISTER_ GAS_DISABLE_MASK_ 0

    // And start gas measurement.
    run_mask := ?
    if variant_ == BME680_VARIANT_:
      run_mask = BME680_RUN_GAS_MASK_
    else if variant_ == BME688_VARIANT_:
      run_mask = BME688_RUN_GAS_MASK_
    else:
      throw "UNKNOWN_VARIANT"
    set_bits_ GAS_RUN_GAS_REGISTER_ run_mask 1

  /**
  Whether the gas measurement is enabled.
  This function is internal and used to temporarily disable the gas measurement when the user only
    asks for temperature, pressure or humidity.
  */
  is_gas_enabled_ -> bool:
    return gas_wait_time_ms_ != 0

  /**
  Computes the heater resistance for the given $degrees.

  The resistance is dependent on the ambient temperature.
  */
  calculate_heater_resistance_ degrees/int -> int:
    // TODO(florian): measure the current ambient temperature.
    amb_temp := 25
    target_temp := degrees

    res_heat_range := calibration_.res_heat_range
    res_heat_val := calibration_.res_heat_val

    // BME680, section 3.3.5
    // BME688, section 3.6.5
    var1 := (calibration_.par_g1 / 16.0) + 49.0
    var2 := ((calibration_.par_g2 / 32768.0) * 0.0005) + 0.00235
    var3 := calibration_.par_g3 / 1024.0
    var4 := var1 * (1.0 + (var2 * target_temp))
    var5 := var4 + (var3 * amb_temp)
    res_heat := 3.4 * ((var5 * (4.0 / (4.0 + res_heat_range)) * (1.0 / (1.0 + (res_heat_val * 0.002)))) - 25)

    return res_heat.to_int

  /**
  Computes the encoded value for the sensor to wait the given $ms when doing the gas measurement.
  */
  calculate_wait_time_ ms/int -> int:
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

  read_calibration_ -> Calibration_:
    calibration := Calibration_

    // Read temperature calibration.
    calibration.par_t1 = registers_.read_u16_le PAR_T1_REGISTER_
    calibration.par_t2 = registers_.read_i16_le PAR_T2_REGISTER_
    calibration.par_t3 = registers_.read_i8 PAR_T3_REGISTER_

    // Read pressure calibration.
    calibration.par_p1  = registers_.read_u16_le  PAR_P1_REGISTER_
    calibration.par_p2  = registers_.read_i16_le  PAR_P2_REGISTER_
    calibration.par_p3  = registers_.read_i8      PAR_P3_REGISTER_
    calibration.par_p4  = registers_.read_i16_le  PAR_P4_REGISTER_
    calibration.par_p5  = registers_.read_i16_le  PAR_P5_REGISTER_
    calibration.par_p6  = registers_.read_i8      PAR_P6_REGISTER_
    calibration.par_p7  = registers_.read_i8      PAR_P7_REGISTER_
    calibration.par_p8  = registers_.read_i16_le  PAR_P8_REGISTER_
    calibration.par_p9  = registers_.read_i16_le  PAR_P9_REGISTER_
    calibration.par_p10 = registers_.read_i8      PAR_P10_REGISTER_

    // Read humidity calibration.
    par_h1 := (registers_.read_u8  PAR_H1_MSB_REGISTER_) << 4
    par_h1 |= (registers_.read_u8 PAR_H1_LSB_REGISTER_) & 0x0F
    calibration.par_h1 = par_h1
    par_h2 := (registers_.read_u8  PAR_H2_MSB_REGISTER_) << 4
    par_h2 |= (registers_.read_u8 PAR_H2_LSB_REGISTER_) >> 4
    calibration.par_h2 = par_h2
    calibration.par_h3 = registers_.read_i8 PAR_H3_REGISTER_
    calibration.par_h4 = registers_.read_i8 PAR_H4_REGISTER_
    calibration.par_h5 = registers_.read_i8 PAR_H5_REGISTER_
    calibration.par_h6 = registers_.read_i8 PAR_H6_REGISTER_
    calibration.par_h7 = registers_.read_i8 PAR_H7_REGISTER_

    // Read gas calibration.
    calibration.par_g1 = registers_.read_i8     PAR_G1_REGISTER_
    calibration.par_g2 = registers_.read_i16_le PAR_G2_REGISTER_
    calibration.par_g3 = registers_.read_i8     PAR_G3_REGISTER_

    // Heater range calculation.
    calibration.res_heat_range = ((registers_.read_u8 RES_HEAT_RANGE_REGISTER_) >> 4) & 0b11

    // Resistance correction factor.
    calibration.res_heat_val = registers_.read_i8 RES_HEAT_VAL_REGISTER_

    // Range switching error.
    if variant_ == BME680_VARIANT_:
      calibration.range_switching_error = (registers_.read_i8 BME680_RANGE_SWITCHING_ERROR_REGISTER_) >> 4
    else if variant_ == BME688_VARIANT_:
      // Do nothing.
    else:
      throw "UNKNOWN_VARIANT"

    return calibration

  /**
  Updates the $register value by replacing the bits selected by the given $mask with the new $value.

  First reads the old value, then clears the old bits, then shifts the new $value into place, and finally
    writes the combined value back to the $register.
  */
  set_bits_ register/int mask/int value/int -> none:
    old := registers_.read_u8 register
    cleared := old & ~mask
    shifted := value
    shifted_mask := 0x01
    while shifted_mask & mask == 0:
      shifted <<= 1
      shifted_mask <<= 1
    shifted &= mask
    registers_.write_u8 register (cleared | shifted)

  /**
  Reads the bits corresponding to the given $mask in the given $register.
  */
  get_bits_ register/int mask/int -> int:
    val := registers_.read_u8 register
    while mask & 0x01 == 0:
      val >>= 1
      mask >>= 1
    return val & mask

/** Calibration coefficients provided by the sensor. */
class Calibration_:
  // Temperature related coefficients.
  par_t1/int := 0
  par_t2/int := 0
  par_t3/int := 0

  // Pressure related coefficients.
  par_p1/int  := 0
  par_p2/int  := 0
  par_p3/int  := 0
  par_p4/int  := 0
  par_p5/int  := 0
  par_p6/int  := 0
  par_p7/int  := 0
  par_p8/int  := 0
  par_p9/int  := 0
  par_p10/int := 0

  // Humidity related coefficients.
  par_h1/int := 0
  par_h2/int := 0
  par_h3/int := 0
  par_h4/int := 0
  par_h5/int := 0
  par_h6/int := 0
  par_h7/int := 0

  // Gas related coefficients.
  par_g1/int := 0
  par_g2/int := 0
  par_g3/int := 0

  res_heat_range/int := 0
  res_heat_val/int   := 0
  range_switching_error/int := 0
