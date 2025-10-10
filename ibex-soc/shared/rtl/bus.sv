// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Simplistic Ibex bus implementation (reworked for variable-latency devices)
 *
 * This module is designed for demo and simulation purposes.
 *
 * Differences from the original:
 * - Accepts at most one in-flight request at a time (single outstanding).
 * - Pulses device_req_o for exactly one cycle when a request is accepted.
 * - Latches the selected host and device (pend_host/pend_device) and routes the
 *   response back whenever the device eventually asserts device_rvalid_i.
 * - Returns a one-cycle error response when no device decodes the address.
 *
 * Arbitration remains strictly priority-based (highest index wins).
 */

module bus #(
  parameter int NrDevices    = 1,
  parameter int NrHosts      = 1,
  parameter int DataWidth    = 32,
  parameter int AddressWidth = 32
) (
  input                           clk_i,
  input                           rst_ni,

  // Hosts (masters)
  input                           host_req_i    [NrHosts],
  output logic                    host_gnt_o    [NrHosts],

  input        [AddressWidth-1:0] host_addr_i   [NrHosts],
  input                           host_we_i     [NrHosts],
  input        [ DataWidth/8-1:0] host_be_i     [NrHosts],
  input        [   DataWidth-1:0] host_wdata_i  [NrHosts],
  output logic                    host_rvalid_o [NrHosts],
  output logic [   DataWidth-1:0] host_rdata_o  [NrHosts],
  output logic                    host_err_o    [NrHosts],

  // Devices (slaves)
  output logic                    device_req_o    [NrDevices],

  output logic [AddressWidth-1:0] device_addr_o   [NrDevices],
  output logic                    device_we_o     [NrDevices],
  output logic [ DataWidth/8-1:0] device_be_o     [NrDevices],
  output logic [   DataWidth-1:0] device_wdata_o  [NrDevices],
  input                           device_rvalid_i [NrDevices],
  input        [   DataWidth-1:0] device_rdata_i  [NrDevices],
  input                           device_err_i    [NrDevices],

  // Device address map
  input        [AddressWidth-1:0] cfg_device_addr_base [NrDevices],
  input        [AddressWidth-1:0] cfg_device_addr_mask [NrDevices]
);

  localparam int unsigned NumBitsHostSel   = (NrHosts   > 1) ? $clog2(NrHosts)   : 1;
  localparam int unsigned NumBitsDeviceSel = (NrDevices > 1) ? $clog2(NrDevices) : 1;

  // -----------------------------
  // Priority host select (highest index wins)
  // -----------------------------
  logic host_sel_valid;
  logic [NumBitsHostSel-1:0] host_sel_req;

  always_comb begin
    host_sel_valid = 1'b0;
    host_sel_req   = '0;
    for (integer host = NrHosts - 1; host >= 0; host = host - 1) begin
      if (host_req_i[host]) begin
        host_sel_valid = 1'b1;
        host_sel_req   = NumBitsHostSel'(host);
      end
    end
  end

  // -----------------------------
  // Address decode for currently selected host
  // -----------------------------
  logic device_sel_valid;
  logic [NumBitsDeviceSel-1:0] device_sel_req;

  always_comb begin
    device_sel_valid = 1'b0;
    device_sel_req   = '0;
    for (integer device = 0; device < NrDevices; device = device + 1) begin
      if ((host_addr_i[host_sel_req] & cfg_device_addr_mask[device])
            == cfg_device_addr_base[device]) begin
        device_sel_valid = 1'b1;
        device_sel_req   = NumBitsDeviceSel'(device);
      end
    end
  end

  // -----------------------------
  // NEW: single in-flight tracker
  // -----------------------------
  logic                                busy;               // a request is in flight
  logic [NumBitsHostSel-1:0]           pend_host;          // latched host for response
  logic [NumBitsDeviceSel-1:0]         pend_device;        // latched device for response
  logic                                decode_err_pending; // pending decode error response

  // Accept a request only when not busy
  wire issue_req     = !busy && host_sel_valid && host_req_i[host_sel_req] && device_sel_valid;
  wire issue_dec_err = !busy && host_sel_valid && host_req_i[host_sel_req] && !device_sel_valid;

  // -----------------------------
  // In-flight state machine
  // -----------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy               <= 1'b0;
      pend_host          <= '0;
      pend_device        <= '0;
      decode_err_pending <= 1'b0;
    end else begin
      // Launch a new transaction
      if (issue_req) begin
        busy        <= 1'b1;
        pend_host   <= host_sel_req;
        pend_device <= device_sel_req;
      end

      // Launch a decode-error "pseudo transaction"
      if (issue_dec_err) begin
        busy               <= 1'b1;
        pend_host          <= host_sel_req;
        decode_err_pending <= 1'b1;
      end

      // Complete transaction
      if (busy) begin
        if (decode_err_pending) begin
          // Emit one-cycle error response; retire immediately next cycle
          decode_err_pending <= 1'b0;
          busy               <= 1'b0;
        end else if (device_rvalid_i[pend_device]) begin
          // Normal completion on device response
          busy <= 1'b0;
        end
      end
    end
  end

  // -----------------------------
  // Drive devices (one-cycle request pulse when accepted)
  // -----------------------------
  always_comb begin
    for (integer device = 0; device < NrDevices; device = device + 1) begin
      device_req_o[device]   = 1'b0;
      device_we_o[device]    = 1'b0;
      device_addr_o[device]  = '0;
      device_wdata_o[device] = '0;
      device_be_o[device]    = '0;

      if (issue_req && NumBitsDeviceSel'(device) == device_sel_req) begin
        device_req_o[device]   = 1'b1;                             // single-cycle pulse
        device_we_o[device]    = host_we_i[host_sel_req];
        device_addr_o[device]  = host_addr_i[host_sel_req];
        device_wdata_o[device] = host_wdata_i[host_sel_req];
        device_be_o[device]    = host_be_i[host_sel_req];
      end
    end
  end

  // -----------------------------
  // Host grants & response routing
  // -----------------------------
  always_comb begin
    // Defaults
    for (integer host = 0; host < NrHosts; host = host + 1) begin
      host_gnt_o[host]    = 1'b0;
      host_rvalid_o[host] = 1'b0;
      host_err_o[host]    = 1'b0;
      host_rdata_o[host]  = '0;
    end

    // Grant only when we *accept* a request (prevents masters from dropping req too early)
    if (issue_req || issue_dec_err) begin
      host_gnt_o[host_sel_req] = 1'b1; // single-cycle grant
    end

    // While busy, route the response to the latched host
    if (busy) begin
      if (decode_err_pending) begin
        // One-cycle error response for bad decode
        host_rvalid_o[pend_host] = 1'b1;
        host_err_o[pend_host]    = 1'b1;
        host_rdata_o[pend_host]  = '0;
      end else begin
        // Normal device-driven completion
        host_rvalid_o[pend_host] = device_rvalid_i[pend_device];
        host_err_o[pend_host]    = device_err_i[pend_device];
        host_rdata_o[pend_host]  = device_rdata_i[pend_device];
      end
    end
  end

endmodule
