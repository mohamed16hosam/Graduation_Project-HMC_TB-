class coverage extends uvm_subscriber #(hmc_pkt_item);
 `uvm_component_utils(coverage)

  // Variables
     bit   [3:0]      length;
     cmd_encoding_e   command;

  //***********************************************************//
  //*********************** COVERGROUPS ***********************//
  //***********************************************************//
     covergroup cmd_cov;

      hmc_cmd : coverpoint command {
      bins flow[]={ NULL,
                    PRET,
                    TRET,
                    IRTRY};

      bins Write_Requests[]={ WR16,
                              WR32,
                              WR48,
                              WR64,
                              WR80,
                              WR96,
                              WR112,
                              WR128};

      bins Misc_Write_Requests[]={ MD_WR,
                                   BWR,
                                   DUAL_2ADD8 ,
                                   SINGLE_ADD16};

      bins  Posted_Write_Requests[]={ P_WR16,
                                      P_WR32,
                                      P_WR48,
                                      P_WR64,
                                      P_WR80,
                                      P_WR96,
                                      P_WR112,
                                      P_WR128};

      bins Posted_Misc_Write_Requests[]={ P_BWR,
                                          P_DUAL_2ADD8,
                                          P_SINGLE_ADD16};

      bins  Mode_Read_Request[]={MD_RD};

      bins  Read_Requests[]={ RD16,
                              RD32,
                              RD48,
                              RD64,
                              RD80,
                              RD96,
                              RD112,
                              RD128};

      bins Response_Commands[]={RD_RS,
                                WR_RS,
                                MD_RD_RS,
                                MD_WR_RS,
                                ERROR_RS };
      
      }

    endgroup
    
    covergroup pkt_cov;
     
     hmc_pkt_length: coverpoint length{
     bins length[]={[0:8] };}
     
   endgroup
   
  //***********************************************************//
  //********************** FUNCTIONS **************************//
  //***********************************************************//
   function new (string name, uvm_component parent);
    super.new(name, parent);
    cmd_cov = new();
    pkt_cov = new();
    
  endfunction : new

  function void write(hmc_pkt_item t);
    command=t.command;
    length=t.length;
    
    cmd_cov.sample();
    pkt_cov.sample();
    
  endfunction : write
  
endclass : coverage