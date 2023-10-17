
class axi_sequence #(parameter NUM_DATA_BYTES = 64, parameter DWIDTH = 512)  extends uvm_sequence #(valid_data #(.DWIDTH(DWIDTH), .NUM_DATA_BYTES(NUM_DATA_BYTES)));

int unsigned num_packets = 1;				
int unsigned max_pkts_per_cycle = 4;		//-- maximum number of packets sended in one cycle
	

rand hmc_pkt_item_request hmc_items[];
hmc_pkt_item_request hmc_packets_ready[$];
	
int working_pos = 0;
	
	
typedef bit [1+1+1+127:0] valid_tail_header_flit_t;
valid_tail_header_flit_t flit_queue[$];
rand int tag = 0;
	
constraint tag_value_c {
tag >= 0;
tag <  512;
}

valid_data #(.DWIDTH(DWIDTH),.NUM_DATA_BYTES(NUM_DATA_BYTES)) axi4_queue[$];

`uvm_object_param_utils_begin(axi_sequence #(.DWIDTH(DWIDTH),.NUM_DATA_BYTES(NUM_DATA_BYTES)))
`uvm_field_int(num_packets, UVM_DEFAULT | UVM_DEC)
`uvm_field_int(max_pkts_per_cycle, UVM_DEFAULT | UVM_DEC)
`uvm_object_utils_end

`uvm_declare_p_sequencer(axi_sequencer #(.DWIDTH(DWIDTH),.NUM_DATA_BYTES(NUM_DATA_BYTES)))
	

function new(string name="axi_sequence");
super.new(name);
endfunction : new


// cerate request in the queue hmc_items
function void pre_randomize ();
super.pre_randomize();

hmc_items = new[num_packets];
foreach (hmc_items[i]) begin
hmc_items[i] = hmc_pkt_item_request::type_id::create($psprintf("hmc_item[%0d]", i) );
end	
`uvm_info(get_type_name(),$psprintf("%0d HMC packets generated", num_packets), UVM_HIGH)	
endfunction : pre_randomize

	
// generate payload and pack it to the request packet, and divide the packet to flits
function void pack_hmc_packet(hmc_pkt_item_request pkt);
bit bitstream[];
valid_tail_header_flit_t tmp_flit;

int unsigned bitcount;
int unsigned packet_count=1;

bitcount = pkt.pack(bitstream);

pkt_successfully_packed : assert (bitcount > 0);

// divide the packet to flits and store them in flit_queue
// f = flit number
for (int f=0; f<bitcount/128; f++) begin
for (int i=0; i< 128; i++)
tmp_flit[i] = bitstream[f*128+i];
// check if header
tmp_flit[128] = (f==0); 				
// check if tail
tmp_flit[129] = (f==bitcount/128-1); 	
// valid			
tmp_flit[130] = 1'b1; 								

flit_queue.push_back(tmp_flit);
end
endfunction : pack_hmc_packet
	

// assign tuser: header, tail, valid flags, and put flits in axi queue
function void hmc_packet_2_axi_cycles();
 	
valid_data #(.DWIDTH(DWIDTH),.NUM_DATA_BYTES(NUM_DATA_BYTES)) axi4_item;
			
int unsigned FPW     = DWIDTH/128; 
int unsigned HEADERS = 1*FPW;
int unsigned TAILS   = 2*FPW;
int unsigned VALIDS  = 0;
	 	
int unsigned pkts_in_cycle = 0;		//-- HMC tails in current cycle
int unsigned header_in_cycle = 0;		//-- HMC headers in current cycle
int unsigned valids_in_cycle = 0;
hmc_pkt_item_request hmc_pkt;


int flit_offset=0;		//-- flit offset: if First flit-> create new axi_item
valid_tail_header_flit_t current_flit;
valid_tail_header_flit_t next_flit;
	 	
	 	
// create empty valid_data
`uvm_create_on(axi4_item, p_sequencer)
axi4_item.t_data = 0;
axi4_item.t_user = 0;
axi4_item.delay = hmc_packets_ready[0].flit_delay / FPW; //-- measured in flits


// if there are packets ready, divide them to flits		
while (hmc_packets_ready.size() >0 )  begin		
hmc_pkt = hmc_packets_ready.pop_front();	
pack_hmc_packet(hmc_pkt);
			
// write flits in flit_queue in axi4_queue
while( flit_queue.size > 0 ) begin 	//-- flit queue contains flits
				
current_flit = flit_queue.pop_front();
				
if (current_flit[128]) begin 	//-- If current flit is header
flit_offset += hmc_pkt.flit_delay;
end
				
// check if axi4_item is full >> push full axi item to axi4_queue
if ((flit_offset >= FPW) || pkts_in_cycle == max_pkts_per_cycle  ) begin 

`uvm_info(get_type_name(),$psprintf("axi4_item is full (offset = %0d), writing element %0d to queue ", flit_offset, axi4_queue.size()), UVM_MEDIUM)
if (valids_in_cycle != 0)
axi4_queue.push_back(axi4_item);
					
//-- create new AXI4 cycle
`uvm_create_on(axi4_item, p_sequencer)
axi4_item.t_data = 0;
axi4_item.t_user = 0;
					
//-- set AXI4 cycle delay
axi4_item.delay = (flit_offset / FPW) -1;	//-- flit offset contains also empty flits
if (flit_offset % FPW >0)
axi4_item.delay += 1;
					
// reset counter and flit
`uvm_info(get_type_name(),$psprintf("HMC Packets in last cycle: %0d, %0d", pkts_in_cycle, header_in_cycle), UVM_HIGH)
pkts_in_cycle 	= 0;	//-- reset HMC packet counter in AXI4 Cycle
header_in_cycle = 0;
valids_in_cycle = 0;
`uvm_info(get_type_name(),$psprintf("axi_delay is %0d", axi4_item.delay), UVM_MEDIUM)
flit_offset = 0;
end

//-- write flit to axi4_item
for (int i =0;i<128;i++) begin
axi4_item.t_data[(flit_offset*128)+i] = current_flit[i];
end
				
// t_user flags
//-- write valid
axi4_item.t_user[VALIDS	+flit_offset] = current_flit[130];	//-- valid [fpw-1:0]
//-- write header
axi4_item.t_user[HEADERS	+flit_offset] = current_flit[128]; 	//-- only 1 if header
//-- write tail
axi4_item.t_user[TAILS	+flit_offset] = current_flit[129];	//-- only 1 if tail
valids_in_cycle ++;
				
				
if(current_flit[129]) begin		//-- count tails in current cycle
pkts_in_cycle ++;
end
				
if(current_flit[128]) begin		//-- count headers in current cycle
header_in_cycle ++;
end
				
//-- debugging output
if(current_flit[128]) begin
`uvm_info(get_type_name(),$psprintf("FLIT is header at pos %d", flit_offset), UVM_MEDIUM)
end
if(current_flit[129]) begin
`uvm_info(get_type_name(),$psprintf("FLIT is tail at pos %d", flit_offset), UVM_MEDIUM)
end
				
flit_offset++;
end
end
//-- push last axi4_item to axi4_queue
axi4_queue.push_back(axi4_item);
endfunction : hmc_packet_2_axi_cycles
	
// assign tag field to each request packet	
task aquire_tags();
for (int i = working_pos; i < hmc_items.size(); i++) begin
// only register a tag if response required >> all but posted commands
if 	(hmc_items[i].get_command_type() == WRITE_TYPE ||
hmc_items[i].get_command_type() == MISC_WRITE_TYPE ||
hmc_items[i].get_command_type() == READ_TYPE 	   ||
hmc_items[i].get_command_type() == MODE_READ_TYPE)
begin
p_sequencer.handler.get_tag(tag);
end else begin
tag = 0;
end
hmc_items[i].tag = tag;
				
// move packet to ready queue if tag valid
if (tag >= 0) begin
`uvm_info(get_type_name(),$psprintf("Tag for HMC Packet Type %0d is: %0d", hmc_items[i].get_command_type(), hmc_items[i]), UVM_HIGH)
hmc_packets_ready.push_back(hmc_items[i]);
working_pos = i+1;
end else begin
break;	//-- send all already processed AXI4 Cycles if tag_handler can not provide an additional tag
end
end
endtask : aquire_tags
		
task send_axi4_cycles();
valid_data #(.DWIDTH(DWIDTH),.NUM_DATA_BYTES(NUM_DATA_BYTES)) axi4_item;
while( axi4_queue.size() > 0 ) begin
`uvm_info(get_type_name(),$psprintf("axi4_queue contains %0d items", axi4_queue.size()), UVM_MEDIUM)
axi4_item = axi4_queue.pop_front();
if ((axi4_item.t_user == {{(NUM_DATA_BYTES){1'b0}}})) begin
axi4_item.print();
`uvm_fatal("AXI4_Master_Driver", "sent an empty cycle")
end
`uvm_send(axi4_item);
`uvm_info(get_type_name(),$psprintf("\n%s", axi4_item.sprint()), UVM_HIGH)
end
endtask : send_axi4_cycles
	
task body();		
`uvm_info(get_type_name(),$psprintf("HMC Packets to send: %0d", hmc_items.size()), UVM_MEDIUM)
while (hmc_items.size-1 >= working_pos)begin //-- cycle until all hmc_packets have been sent
aquire_tags();
// send all packets with tags
if (hmc_packets_ready.size()>0) begin
// generate axi4_queue
hmc_packet_2_axi_cycles();
// send axi4_queue
send_axi4_cycles();
end 
end
endtask : body

endclass : axi_sequence


