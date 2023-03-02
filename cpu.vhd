-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Ondrej Koumar, xkouma02@stud.fit.vutbr.cz
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

type FSM_STATE is (SInit, SFetch, SDecode, SMoveRight, SMoveLeft, SIncrement, SDecrement, SWriteChar, SWriteChar2, SLoadChar,
					SLoadChar2, SBeginWhile, SWhileCheck0, SDoWhileCheck0, SDoWhileCheckPar, SDoWhileDecode, SDoWhileScan, 
                    SWhileCheckPar, SWhileCheckCNT, SSkipWhile, SWhileSkip, SWhileScan, SWhileDecode, SNull);
							
signal PRESENT_STATE : FSM_STATE;
signal NEXT_STATE : FSM_STATE;

signal SIG_PC : std_logic_vector(12 downto 0);
signal SIG_PTR : std_logic_vector(12 downto 0);
signal SIG_CNT : std_logic_vector(7 downto 0);

signal CNT_INC : std_logic;
signal CNT_DEC : std_logic;

signal PTR_INC : std_logic;
signal PTR_DEC : std_logic;

signal PC_INC : std_logic;
signal PC_DEC : std_logic;

signal SEL_MUX1 : std_logic;
signal SEL_MUX2 : std_logic_vector(1 downto 0);

begin

--- FSM PRESENT STATE REGISTER ---
STATE_REGISTER: process(RESET, CLK)
begin

	if (EN = '0') then
		PRESENT_STATE <= SInit;
	elsif (rising_edge(CLK) and EN = '1') then
		PRESENT_STATE <= NEXT_STATE;
	end if;
	
end process;

--- FSM NEXT STATE LOGIC ---
NEXT_STATE_LOGIC: process(PRESENT_STATE, CLK)
begin
    
    CNT_INC <= '0';
    CNT_DEC <= '0';
    PC_INC <= '0';
    PC_DEC <= '0';
    PTR_INC <= '0';
    PTR_DEC <= '0';
    SEL_MUX1 <= '0';
    SEL_MUX2 <= "00";
    DATA_RDWR <= '0';
    DATA_EN <= '1';
    IN_REQ <= '0';
    OUT_WE <= '0';
    
	case PRESENT_STATE is
	
		when SInit =>
			NEXT_STATE <= SFetch;
	
		when SFetch =>
            NEXT_STATE <= SDecode;
			
		when SDecode =>

            SEL_MUX1 <= '1';
		
			case DATA_RDATA is
				
				-- '>' --
				when X"3E" =>
					NEXT_STATE <= SMoveRight;
					
				-- '<' --
				when X"3C" =>
					NEXT_STATE <= SMoveLeft;
					
				-- '+' --
				when X"2B" =>
					NEXT_STATE <= SIncrement;
					
				-- '-' --
				when X"2D" =>
					NEXT_STATE <= SDecrement;
					
				-- '[' -- 
				when X"5B" =>
					NEXT_STATE <= SBeginWhile;
					
				-- ']' --
				when X"5D" =>
					NEXT_STATE <= SWhileCheck0;
					
				-- ')' --
				when X"29" =>
					NEXT_STATE <= SDoWhileCheck0;
					
				-- '.' --	
				when X"2E" =>
					NEXT_STATE <= SWriteChar;
					
				-- ',' --
				when X"2C" =>
					NEXT_STATE <= SLoadChar;
					
				-- null --
				when X"00" =>
					NEXT_STATE <= SNull;

				when others =>
                    PC_INC <= '1';
					NEXT_STATE <= SFetch;
					
			end case;
			
		when SMoveRight =>
			PTR_INC <= '1';
            SEL_MUX1 <= '1';
			PC_INC <= '1';
		
			NEXT_STATE <= SFetch;
			
		when SMoveLeft =>
			PTR_DEC <= '1';
            SEL_MUX1 <= '1';
			PC_INC <= '1';
			
			NEXT_STATE <= SFetch;
			
		when SIncrement =>
			DATA_RDWR <= '1';
			SEL_MUX1 <= '1';
			SEL_MUX2 <= "01";
			PC_INC <= '1';
		
			NEXT_STATE <= SFetch;
			
		when SDecrement =>  
            DATA_RDWR <= '1';
            SEL_MUX1 <= '1';
            SEL_MUX2 <= "10";
            PC_INC <= '1';
            
            NEXT_STATE <= SFetch;

		when SWriteChar =>
			NEXT_STATE <= SWriteChar;
            SEL_MUX1 <= '1';

            if (OUT_BUSY = '0') then
                NEXT_STATE <= SWriteChar2;
            end if;

        when SWriteChar2 =>
            SEL_MUX1 <= '1';
            OUT_DATA <= DATA_RDATA;
            OUT_WE <= '1';
            PC_INC <= '1';
            NEXT_STATE <= SFetch;              
			
		when SLoadChar =>
			NEXT_STATE <= SLoadChar;
            IN_REQ <= '1';
            SEL_MUX1 <= '1';
			
			if (IN_VLD = '1') then
				NEXT_STATE <= SLoadChar2;
			end if;
			
        when SLoadChar2 =>
            PC_INC <= '1';		
            DATA_RDWR <= '1';
            SEL_MUX1 <= '1';

            NEXT_STATE <= SFetch;
            
        when SDoWhileCheck0 =>

            if (DATA_RDATA = X"00") then
                NEXT_STATE <= SFetch;
                PC_INC <= '1';
            else 
                NEXT_STATE <= SDoWhileScan;
                PC_DEC <= '1';
                CNT_INC <= '1';
            end if;

        when SDoWhileScan =>
            NEXT_STATE <= SDoWhileDecode;

        when SDoWhileDecode =>
            NEXT_STATE <= SDoWhileDecode;
            
            if (DATA_RDATA = X"29") then
                CNT_INC <= '1';
                PC_DEC <= '1';
            elsif (DATA_RDATA = X"28") then
                CNT_DEC <= '1';
                NEXT_STATE <= SDoWhileCheckPar;
            else
                PC_DEC <= '1';
            end if;

        when SDoWhileCheckPar =>
            
            if (SIG_CNT = X"00") then
                NEXT_STATE <= SFetch;
                PC_INC <= '1';
            else
                NEXT_STATE <= SDoWhileDecode;
                PC_DEC <= '1';
            end if;
        
        when SBeginWhile =>
            NEXT_STATE <= SFetch;
            PC_INC <= '1';
            
            if (DATA_RDATA = X"00") then
                NEXT_STATE <= SWhileSkip;
                CNT_INC <= '1';
            end if;

        when SWhileSkip =>
            NEXT_STATE <= SSkipWhile;

        when SSkipWhile =>
            NEXT_STATE <= SWhileSkip;
            PC_INC <= '1';
        
            if (DATA_RDATA = X"5B") then
                CNT_INC <= '1';
            elsif (DATA_RDATA = X"5D") then
                CNT_DEC <= '1';
                NEXT_STATE <= SWhileCheckCNT;
            end if;

        when SWhileCheckCNT =>
            NEXT_STATE <= SWhileSkip;

            if (SIG_CNT = X"00") then
                NEXT_STATE <= SFetch;
            end if;

        when SWhileCheck0 =>

            if (DATA_RDATA = X"00") then
                NEXT_STATE <= SFetch;
                PC_INC <= '1';
            else
                NEXT_STATE <= SWhileScan;
                PC_DEC <= '1';
                CNT_INC <= '1';
            end if;

        when SWhileScan =>
            NEXT_STATE <= SWhileDecode;

        when SWhileDecode =>

            if (DATA_RDATA = X"5B") then
                CNT_DEC <= '1';
                NEXT_STATE <= SWhileCheckPar;
            elsif (DATA_RDATA = X"5D") then
                CNT_INC <= '1';
                PC_DEC <= '1';
            else
                PC_DEC <= '1';
            end if;

        when SWhileCheckPar =>

            if (SIG_CNT = X"00") then
                NEXT_STATE <= SFetch;
                PC_INC <= '1';
            else
                NEXT_STATE <= SWhileDecode;
                PC_DEC <= '1';
            end if;

		when SNull =>
			NEXT_STATE <= SNull;
            DATA_EN <= '0';
			
		when others =>
			NEXT_STATE <= SFetch;
			PC_INC <= '1';
			
	end case;
	
end process;

--- While loop counter ---
CNT: process(CLK, RESET)
begin

	if (RESET = '1') then
		SIG_CNT <= (others => '0');
		
	elsif (rising_edge(CLK)) then
	
		if (CNT_INC = '1') then
			SIG_CNT <= SIG_CNT + 1;
		elsif (CNT_DEC = '1') then
			SIG_CNT <= SIG_CNT - 1;	
		end if;
		
	end if;

end process;

--- Program counter --- 
PC: process(CLK, RESET)
begin

	if (RESET = '1') then
		SIG_PC <= (others => '0');
		
	elsif (rising_edge(CLK)) then
	
		if (PC_INC = '1') then
		
			if (SIG_PC = X"0FFF") then
				SIG_PC <= '0' & X"000";	
			else
				SIG_PC <= SIG_PC + 1;
			end if;
			
		elsif (PC_DEC = '1') then
		
			if (SIG_PC = X"0000") then
				SIG_PC <= '0' & X"FFF";
			else
				SIG_PC <= SIG_PC - 1;
			end if;
			
		end if;
		
	end if;

end process;

--- Memory pointer ---
PTR: process(CLK, RESET)
begin

	if (RESET = '1') then
	
		SIG_PTR <= '1' & X"000";
		
	elsif rising_edge(CLK) then
	
		if (PTR_INC = '1') then
		
			if (SIG_PTR = X"1FFF") then
				SIG_PTR <= '1' & x"000";
			else
				SIG_PTR <= SIG_PTR + 1;
			end if;
			
		elsif (PTR_DEC = '1') then
		
			if (SIG_PTR = X"1000") then
				SIG_PTR <= '1' & X"FFF";
			else
				SIG_PTR <= SIG_PTR - 1;
			end if;
			
			
		end if;
		
	end if;

end process;

MUX1: process(SEL_MUX1, SIG_PC, SIG_PTR)
begin

    if (SEL_MUX1 = '0') then
        DATA_ADDR <= SIG_PC;
    else
        DATA_ADDR <= SIG_PTR;
    end if;

end process;

MUX2: process(SEL_MUX2, IN_DATA, DATA_RDATA)
begin

    if (SEL_MUX2 = "00") then
        DATA_WDATA <= IN_DATA;
    elsif (SEL_MUX2 = "01") then
        DATA_WDATA <= DATA_RDATA + 1;
    elsif (SEL_MUX2 = "10") then
        DATA_WDATA <= DATA_RDATA - 1;
    else
        DATA_WDATA <= DATA_RDATA;
    end if;

end process;

end behavioral;


