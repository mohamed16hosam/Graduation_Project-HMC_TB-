module tb_top;

  parameter FPW                   = 4;        //Legal Values: 2,4,6,8
  parameter LOG_FPW               = 2;        //Legal Values: 1 for FPW=2 ,2 for FPW=4 ,3 for FPW=6/8
  parameter DWIDTH                = FPW*128;  //Leave untouched
  //Define HMC interface width
  parameter LOG_NUM_LANES         = 3;                //Set 3 for half-width, 4 for full-width
  parameter NUM_LANES             = 2**LOG_NUM_LANES; //Leave untouched
  parameter NUM_DATA_BYTES        = FPW*16;           //Leave untouched
  //Define width of the register file
  parameter HMC_RF_WWIDTH         = 64;   //Leave untouched    
  parameter HMC_RF_RWIDTH         = 64;   //Leave untouched
  parameter HMC_RF_AWIDTH         = 4;    //Leave untouched
  //Configure the Functionality
  parameter LOG_MAX_RX_TOKENS     = 8;    //Set the depth of the RX input buffer. Must be >= LOG(rf_rx_buffer_rtc) in the RF. Dont't care if OPEN_RSP_MODE=1
  parameter LOG_MAX_HMC_TOKENS    = 10;   //Set the depth of the HMC input buffer. Must be >= LOG of the corresponding field in the HMC internal register
  parameter HMC_RX_AC_COUPLED     = 0;    //Set to 0 to bypass the run length limiter, saves logic and 1 cycle delay
  parameter DETECT_LANE_POLARITY  = 0;    //Set to 0 if lane polarity is not applicable, saves logic
  parameter CTRL_LANE_POLARITY    = 0;    //Set to 0 if lane polarity is not applicable or performed by the transceivers, saves logic and 1 cycle delay
                                          //If set to 1: Only valid if DETECT_LANE_POLARITY==1, otherwise tied to zero
  parameter CTRL_LANE_REVERSAL    = 0;    //Set to 0 if lane reversal is not applicable or performed by the transceivers, saves logic
  parameter CTRL_SCRAMBLERS       = 1;    //Set to 0 to remove the option to disable (de-)scramblers for debugging, saves logic
  parameter OPEN_RSP_MODE         = 0;    //Set to 1 if running response open loop mode, bypasses the RX input buffer
  parameter RX_RELAX_INIT_TIMING  = 1;    //Per default, incoming TS1 sequences are only checked for the lane independent h'F0 sequence. Save resources and
                                          //eases timing closure. !Lane reversal is still detected
  parameter RX_BIT_SLIP_CNT_LOG   = 5;    //Define the number of cycles between bit slips. Refer to the transceiver user guide
                                          //Example: RX_BIT_SLIP_CNT_LOG=5 results in 2^5=32 cycles between two bit slips
  parameter SYNC_AXI4_IF          = 1;    //Set to 1 if AXI IF is synchronous to clk_hmc to use simple fifos
  parameter XIL_CNT_PIPELINED     = 0;    //If Xilinx counters are used, set to 1 to enabled output register pipelining
  //Set the direction of bitslip. Set to 1 if bitslip performs a shift right, otherwise set to 0 (see the corresponding transceiver user guide)
  parameter BITSLIP_SHIFT_RIGHT   = 1;    
  //Debug Params
  parameter DBG_RX_TOKEN_MON      = 1;    //Set to 0 to remove the RX Link token monitor, saves logic

  parameter FLIT_SIZE = 128;
  parameter CLK_PERIOD = 4.27 ; 

  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import tb_params_pkg::*;
  import tb_pkg::* ;
  import seq_pkg::* ;
  import test_pkg::* ;

  logic clk;
  logic res_n;

  rf_if #(.HMC_RF_WWIDTH(HMC::HMC_RF_WWIDTH),
          .HMC_RF_RWIDTH(HMC::HMC_RF_RWIDTH),
          .HMC_RF_AWIDTH(HMC::HMC_RF_AWIDTH))
    RF (.clk(clk), .res_n(res_n));

  hmc_agent_if #(.DWIDTH(HMC::DWIDTH), 
                 .NUM_LANES(HMC::NUM_LANES), 
                 .FPW(HMC::FPW),
                 .FLIT_SIZE(HMC::FLIT_SIZE))
  HMC_IF (.clk(clk), .res_n(res_n));

 axi_interface #(.DWIDTH(HMC::DWIDTH),
                 .NUM_DATA_BYTES(HMC::NUM_DATA_BYTES))
  AXI_IF (.clk(clk), .res_n(res_n));

  openhmc_top #(.FPW(FPW),
                .LOG_FPW(LOG_FPW),
                .DWIDTH(DWIDTH),
                .LOG_NUM_LANES(LOG_NUM_LANES),
                .NUM_DATA_BYTES(NUM_DATA_BYTES),
                .HMC_RF_WWIDTH(HMC_RF_WWIDTH),
                .HMC_RF_RWIDTH(HMC_RF_RWIDTH),
                .HMC_RF_AWIDTH(HMC_RF_AWIDTH),
                .LOG_MAX_RX_TOKENS(LOG_MAX_RX_TOKENS),
                .LOG_MAX_HMC_TOKENS(LOG_MAX_HMC_TOKENS),
                .HMC_RX_AC_COUPLED(HMC_RX_AC_COUPLED),
                .DETECT_LANE_POLARITY(DETECT_LANE_POLARITY),
                .CTRL_LANE_POLARITY(CTRL_LANE_POLARITY),
                .CTRL_LANE_REVERSAL(CTRL_LANE_REVERSAL),
                .CTRL_SCRAMBLERS(CTRL_SCRAMBLERS),
                .OPEN_RSP_MODE(OPEN_RSP_MODE),
                .RX_RELAX_INIT_TIMING(RX_RELAX_INIT_TIMING),
                .RX_BIT_SLIP_CNT_LOG(RX_BIT_SLIP_CNT_LOG),
                .SYNC_AXI4_IF(SYNC_AXI4_IF),
                .XIL_CNT_PIPELINED(XIL_CNT_PIPELINED),
                .BITSLIP_SHIFT_RIGHT(BITSLIP_SHIFT_RIGHT),
                .DBG_RX_TOKEN_MON(DBG_RX_TOKEN_MON))

    dut (.clk_hmc(clk),
         .res_n_hmc(res_n),
         .res_n_user(res_n),
         .clk_user(clk),
         //axi interface
         .s_axis_tx_TVALID(AXI_IF.t_valid),
         .s_axis_tx_TREADY(AXI_IF.t_ready),
         .s_axis_tx_TDATA(AXI_IF.t_data),
         .s_axis_tx_TUSER(AXI_IF.t_user),
         .m_axis_rx_TVALID(AXI_IF.rx_valid),
         .m_axis_rx_TREADY(AXI_IF.rx_ready),
         .m_axis_rx_TDATA(AXI_IF.rx_data),
         .m_axis_rx_TUSER(AXI_IF.rx_user),
         // transceiver
         .phy_data_tx_link2phy(HMC_IF.phy_data_tx_link2phy),
         .phy_data_rx_phy2link(HMC_IF.phy_data_rx_phy2link),
         .phy_bit_slip(HMC_IF.phy_bit_slip), //Must be connected if DETECT_LANE_POLARITY==1 AND CTRL_LANE_POLARITY=0
         .phy_lane_polarity(HMC_IF.phy_lane_polarity), //All 0 if CTRL_LANE_POLARITY=1
         .phy_tx_ready(HMC_IF.phy_tx_ready), //Optional information to RF
         .phy_rx_ready(HMC_IF.phy_rx_ready), //Release RX descrambler reset when PHY ready
         .phy_init_cont_set(HMC_IF.phy_init_cont_set), //Can be used to release transceiver reset if used
         // hmc
         .P_RST_N(HMC_IF.P_RST_N),
         .LXRXPS(HMC_IF.LXRXPS),
         .LXTXPS(HMC_IF.LXTXPS),
         .FERR_N(HMC_IF.FERR_N),
         // register file
         .rf_address(RF.rf_address),
         .rf_read_data(RF.rf_read_data),
         .rf_invalid_address(RF.rf_invalid_address),
         .rf_access_complete(RF.rf_access_complete),
         .rf_read_en(RF.rf_read_enable),
         .rf_write_en(RF.rf_write_enable),
         .rf_write_data(RF.rf_write_data)
         );

 bind openhmc_top : dut openhmc_sva #(.FPW(FPW),
                                       .LOG_FPW(LOG_FPW),
                                       .DWIDTH(DWIDTH),
                                       .LOG_NUM_LANES(LOG_NUM_LANES),
                                       .NUM_DATA_BYTES(NUM_DATA_BYTES),
                                       .HMC_RF_WWIDTH(HMC_RF_WWIDTH),
                                       .HMC_RF_RWIDTH(HMC_RF_RWIDTH),
                                       .HMC_RF_AWIDTH(HMC_RF_AWIDTH),
                                       .LOG_MAX_RX_TOKENS(LOG_MAX_RX_TOKENS),
                                       .LOG_MAX_HMC_TOKENS(LOG_MAX_HMC_TOKENS),
                                       .HMC_RX_AC_COUPLED(HMC_RX_AC_COUPLED),
                                       .DETECT_LANE_POLARITY(DETECT_LANE_POLARITY),
                                       .CTRL_LANE_POLARITY(CTRL_LANE_POLARITY),
                                       .CTRL_LANE_REVERSAL(CTRL_LANE_REVERSAL),
                                       .CTRL_SCRAMBLERS(CTRL_SCRAMBLERS),
                                       .OPEN_RSP_MODE(OPEN_RSP_MODE),
                                       .RX_RELAX_INIT_TIMING(RX_RELAX_INIT_TIMING),
                                       .RX_BIT_SLIP_CNT_LOG(RX_BIT_SLIP_CNT_LOG),
                                       .SYNC_AXI4_IF(SYNC_AXI4_IF),
                                       .XIL_CNT_PIPELINED(XIL_CNT_PIPELINED),
                                       .BITSLIP_SHIFT_RIGHT(BITSLIP_SHIFT_RIGHT),
                                       .DBG_RX_TOKEN_MON(DBG_RX_TOKEN_MON)) 
                         openhmc_sva_1 (.*);
                         

initial begin
  uvm_config_db#(virtual rf_if #(HMC::HMC_RF_WWIDTH, HMC::HMC_RF_RWIDTH, HMC::HMC_RF_AWIDTH))::set(null, "uvm_test_top", "RF", RF);
  uvm_config_db#(virtual hmc_agent_if #(HMC::DWIDTH, HMC::NUM_LANES, HMC::FPW, HMC::FLIT_SIZE))::set(null, "uvm_test_top", "HMC_IF", HMC_IF);
  uvm_config_db#(virtual axi_interface #(HMC::NUM_DATA_BYTES, HMC::DWIDTH))::set(null, "uvm_test_top", "AXI_IF", AXI_IF);
  run_test();
end

initial begin
  res_n = 0;
  clk = 0;
  repeat(10) begin
    //#10ns
    #(CLK_PERIOD/2)
     clk = ~clk;
  end
  res_n = 1;
  forever begin
    //#10ns 
    #(CLK_PERIOD/2)
    clk = ~clk;
  end
end

endmodule : tb_top