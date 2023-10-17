class env extends  uvm_env;
  
  `uvm_component_utils(env);

  vsequencer         m_vseqr;

  env_cfg            cfg;

  rf_agent_t         m_rf_agent;
  // Register layer adapter
  rf_reg2hmc_adapter m_rf_reg2hmc_adapter;
  // Register predictor
  uvm_reg_predictor#(rf_item) m_rf_hmc2reg_predictor;
// HMC agent and configuration
  hmc_agent_t hmc_agent_h ;
  
// axi agent   
  axi_agent_t axi_agent_h;

  scoreboard m_scoreboard;
  coverage m_coverage;
   
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

endclass : env


function env::new(string name, uvm_component parent);
  super.new(name,parent);
endfunction : new


function void env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if(!uvm_config_db #(env_cfg)::get(this, "","m_env_cfg", cfg))
    `uvm_fatal("ENV_CONFIG_LOAD", "Failed to get env_cfg from uvm_config_db")

  uvm_config_db#(rf_agent_cfg_t)::set(this, "m_rf_agent*", "rf_agent_cfg_t", cfg.m_rf_agent_cfg);
  uvm_config_db#(hmc_agent_config_t)::set(this, "hmc_agent_h*", "hmc_agent_config_t", cfg.m_hmc_agent_cfg);
  uvm_config_db#(axi_config_t)::set(this, "axi_agent_h*", "axi_config_t", cfg.m_axi_cfg);


  m_rf_agent = rf_agent_t::type_id::create("m_rf_agent",this);

  // Build the register model predictor
  m_rf_hmc2reg_predictor = uvm_reg_predictor#(rf_item)::type_id::create("m_rf_hmc2reg_predictor", this);
  m_rf_reg2hmc_adapter = rf_reg2hmc_adapter::type_id::create("m_rf_reg2hmc_adapter");


  hmc_agent_h = hmc_agent_t::type_id::create("hmc_agent_h",this); 

  axi_agent_h = axi_agent_t::type_id::create("axi_agent_h",this); 

  m_vseqr    = vsequencer::type_id::create("m_vseqr" , this);

  m_scoreboard = scoreboard::type_id::create("m_scoreboard",this);
  m_coverage = coverage::type_id::create("m_coverage",this);

endfunction : build_phase


function void env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  //************************************************************************//
  // Only set up register sequencer layering if the reg block is the top block
  // If it isn't, then the top level environment will set up the correct sequencer
  // and predictor
  if(cfg.rf_rb.get_parent() == null) begin
    `uvm_info("env_connect_phase","set up register block seqr", UVM_MEDIUM)
    if(cfg.m_rf_agent_cfg.active == UVM_ACTIVE) begin
      cfg.rf_rb.rf_map.set_sequencer(m_rf_agent.m_seqr, m_rf_reg2hmc_adapter);
    end
    // Register prediction part:
    // Set the predictor map:
    m_rf_hmc2reg_predictor.map = cfg.rf_rb.rf_map;
    // Set the predictor adapter:
    m_rf_hmc2reg_predictor.adapter = m_rf_reg2hmc_adapter;
    // Disable the register models auto-prediction
    cfg.rf_rb.rf_map.set_auto_predict(0);
    // Connect the predictor to the bus agent monitor analysis port
    m_rf_agent.rf_ap.connect(m_rf_hmc2reg_predictor.bus_in);
  end
  //************************************************************************//
  m_vseqr.m_rf_seqr = m_rf_agent.m_seqr;
  m_vseqr.m_seqr_hmc_agent = hmc_agent_h.sequencer_hmc_agent_h;
  m_vseqr.m_axi_sqr = axi_agent_h.a_sequencer;

  // Connect Coverage and Scoreboard analysis ports
  // Syntax :
  //m_agent.ap_name.connect(m_scoreboard.ap_name.analysis_export);
  
  axi_agent_h.mon_request.connect(m_coverage.analysis_export);  // Should send the hmc_pkt_item
  axi_agent_h.mon_response.connect(m_coverage.analysis_export); // Should send the hmc_pkt_item
  hmc_agent_h.mon_req_ap.connect(m_coverage.analysis_export);
  hmc_agent_h.mon_res_ap.connect(m_coverage.analysis_export);

  //axi_agent_h.mon_request.connect(m_scoreboard.axi4_hmc_req.analysis_export);  // Should send the hmc_pkt_item
  //axi_agent_h.mon_response.connect(m_scoreboard.axi4_hmc_rsp.analysis_export);  // Should send the hmc_pkt_item
  //hmc_agent_h.mon_req_ap.connect(m_scoreboard.hmc_req_port);
  //hmc_agent_h.mon_res_ap.connect(m_scoreboard.hmc_rsp_port);

endfunction : connect_phase
