/*

Copyright (c) 2016-2018 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * Generic IDDR module
 */
module iddr #
(
    // target ("SIM", "GENERIC", "XILINX", "ALTERA")
    parameter TARGET = "GENERIC",
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire             clk,

    input  wire [WIDTH-1:0] d,

    output wire [WIDTH-1:0] q1,
    output wire [WIDTH-1:0] q2
);

/*

Provides a consistent input DDR flip flop across multiple FPGA families
              _____       _____       _____       _____       ____
    clk  ____/     \_____/     \_____/     \_____/     \_____/
         _ _____ _____ _____ _____ _____ _____ _____ _____ _____ _
    d    _X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7__X_D8__X_
         _______ ___________ ___________ ___________ ___________ _
    q1   _______X___________X____D0_____X____D2_____X____D4_____X_
         _______ ___________ ___________ ___________ ___________ _
    q2   _______X___________X____D1_____X____D3_____X____D5_____X_

*/

genvar n;

generate

if (TARGET == "XILINX") begin
    for (n = 0; n < WIDTH; n = n + 1) begin : iddr
        if (IODDR_STYLE == "IODDR") begin
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .SRTYPE("ASYNC")
            )
            iddr_inst (
                .Q1(q1[n]),
                .Q2(q2[n]),
                .C(clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end else if (IODDR_STYLE == "IODDR2") begin
            IDDR2 #(
                .DDR_ALIGNMENT("C0")
            )
            iddr_inst (
                .Q0(q1[n]),
                .Q1(q2[n]),
                .C0(clk),
                .C1(~clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    end
end else if (TARGET == "ALTERA") begin
    wire [WIDTH-1:0] q1_int;
    reg [WIDTH-1:0] q1_delay;

    altddio_in #(
        .WIDTH(WIDTH),
        .POWER_UP_HIGH("OFF")
    )
    altddio_in_inst (
        .aset(1'b0),
        .datain(d),
        .inclocken(1'b1),
        .inclock(clk),
        .aclr(1'b0),
        .dataout_h(q1_int),
        .dataout_l(q2)
    );

    always @(posedge clk) begin
        q1_delay <= q1_int;
    end

    assign q1 = q1_delay;
end else if (TARGET == "ALTERA_MAX10") begin
    reg [2*WIDTH-1:0] q_delay;
    wire [2*WIDTH-1:0] q_int;
    altera_gpio_lite #(
      .PIN_TYPE                                 ("input"),
      .SIZE                                     (WIDTH),
      .REGISTER_MODE                            ("ddr"),
      .BUFFER_TYPE                              ("single-ended"),
      .ASYNC_MODE                               ("none"),
      .SYNC_MODE                                ("none"),
      .BUS_HOLD                                 ("false"),
      .OPEN_DRAIN_OUTPUT                        ("false"),
      .ENABLE_OE_PORT                           ("false"),
      .ENABLE_NSLEEP_PORT                       ("false"),
      .ENABLE_CLOCK_ENA_PORT                    ("false"),
      .SET_REGISTER_OUTPUTS_HIGH                ("false"),
      .INVERT_OUTPUT                            ("false"),
      .INVERT_INPUT_CLOCK                       ("false"),
      .USE_ONE_REG_TO_DRIVE_OE                  ("false"),
      .USE_DDIO_REG_TO_DRIVE_OE                 ("false"),
      .USE_ADVANCED_DDR_FEATURES                ("false"),
      .USE_ADVANCED_DDR_FEATURES_FOR_INPUT_ONLY ("false"),
      .ENABLE_OE_HALF_CYCLE_DELAY               ("true"),
      .INVERT_CLKDIV_INPUT_CLOCK                ("false"),
      .ENABLE_PHASE_INVERT_CTRL_PORT            ("false"),
      .ENABLE_HR_CLOCK                          ("false"),
      .INVERT_OUTPUT_CLOCK                      ("false"),
      .INVERT_OE_INCLOCK                        ("false"),
      .ENABLE_PHASE_DETECTOR_FOR_CK             ("false")
    ) max10_iddr_inst (
      .inclock         (clk), // inclock.export
      .dout            (q_int),    //    dout.export
      .pad_in          (d),  //  pad_in.export
      .inclocken       (1'b1),    // (terminated)
      .fr_clock        (),        // (terminated)
      .hr_clock        (),        // (terminated)
      .invert_hr_clock (1'b0),    // (terminated)
      .outclock        (1'b0),    // (terminated)
      .outclocken      (1'b0),    // (terminated)
      .phy_mem_clock   (1'b0),    // (terminated)
      .mimic_clock     (),        // (terminated)
      .din             ({WIDTH{2'b00}}),   // (terminated)
      .pad_io          (),        // (terminated)
      .pad_io_b        (),        // (terminated)
      .pad_in_b        ({WIDTH{1'b0}}),    // (terminated)
      .pad_out         (),        // (terminated)
      .pad_out_b       (),        // (terminated)
      .aset            (1'b0),    // (terminated)
      .aclr            (1'b0),    // (terminated)
      .sclr            (1'b0),    // (terminated)
      .nsleep          ({WIDTH{1'b0}}),    // (terminated)
      .oe              ({WIDTH{1'b0}})     // (terminated)
    );

    always @(posedge clk) begin
      q_delay <= q_int;
    end
    assign {q2, q1} = q_delay;
end else begin
    reg [WIDTH-1:0] d_reg_1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] d_reg_2 = {WIDTH{1'b0}};

    reg [WIDTH-1:0] q_reg_1 = {WIDTH{1'b0}};
    reg [WIDTH-1:0] q_reg_2 = {WIDTH{1'b0}};

    always @(posedge clk) begin
        d_reg_1 <= d;
    end

    always @(negedge clk) begin
        d_reg_2 <= d;
    end

    always @(posedge clk) begin
        q_reg_1 <= d_reg_1;
        q_reg_2 <= d_reg_2;
    end

    assign q1 = q_reg_1;
    assign q2 = q_reg_2;
end

endgenerate

endmodule
