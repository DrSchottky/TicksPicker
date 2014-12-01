-- Coded by DrSchottky. Based on Alibaba's code.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.STD_LOGIC_UNSIGNED.all;

-- SDA payload is for Phat/Trinity HANA. Feel free to adjust it for Coronas
entity main is
generic (  
	SDA_SLOW_BITS 	: STD_LOGIC_VECTOR(0 to 271) := b"10011111111111100000000000000000000111111111111110000000011111111000011111111110000000000000000000011110000000011111100001111000000001111111111110000111111000000000000000011110000000000001111111111000000000000000000000000000011111100000000000000000000000011111111111111001";
   SDA_FAST_BITS 	: STD_LOGIC_VECTOR(0 to 271) := b"10011111111111100000000000000000000111111111111110000000011111111000011111111110000000000000000000011110000000011111100001111000000001111111111110000111111111100000000000000000000000000001111110000000000000000111111110000000011111100000000000000000000000011110000111111001";
   SCL_BITS 		: STD_LOGIC_VECTOR(0 to 271) := b"11001100110011001100110011001100110011000011001100110011001100110011001100110000110011001100110011001100110011001100001100110011001100110011001100110011000011001100110011001100110011001100110000110011001100110011001100110011001100001100110011001100110011001100110011000011"
  );
  
port (
	DBG : out STD_LOGIC := '0';
	POSTBIT : in STD_LOGIC;
   CLK : in STD_LOGIC;
   CPU_RESET : inout STD_LOGIC := 'Z';
   SDA : out  STD_LOGIC := 'Z';
   SCL : out  STD_LOGIC := 'Z';
	POST_BUS_OUT : out STD_LOGIC_VECTOR (7 downto 0) --I used DGX's DIP bus
	);
end main;

architecture counter of main is

-- User defined settings
constant measure_width : integer := 24;--24 bits should be enough
constant postcnt_max : integer := ;
constant post_downclock_start : integer := ;
constant post_downclock_end : integer := ;
constant measured_post : integer := ;



-- Default stuff
constant i2ccnt_max : integer := 271;
constant i2c_divider : integer := 187; --This works with 150Mhz xtal
signal postcnt : integer range 0 to postcnt_max := 0;
signal i2ccnt : integer range 0 to i2ccnt_max := i2ccnt_max;
signal divider_cnt : integer range 0 to i2c_divider := 0;
signal ticks : integer range 0 to 2**measure_width -1 := 0;
signal vector: STD_LOGIC_VECTOR((measure_width -1) downto 0) := std_logic_vector(to_signed(0,measure_width));
signal pslo : STD_LOGIC := '0';
signal slo : STD_LOGIC := '0';
signal i2c_clock : std_logic := '0';
signal sda_out : std_logic := '1';
signal scl_out : std_logic := '1';

begin	
	
-- post count
	process (POSTBIT) is
	begin
		if POSTBIT'event then
			if (CPU_RESET = '0') then
				postcnt <= 0;
			else
				if postcnt /= postcnt_max then
					postcnt <= postcnt + 1;
				end if;
			end if;
		end if;
	end process;

-- slow flag
	process (postcnt) is
	begin
		if (postcnt >= post_downclock_start and postcnt <= post_downclock_end) then
			slo <= '1';
		else
			slo <= '0';
		end if;
	end process;
	
-- main counter 
	process (CLK)
	begin
		if CLK' event then
			if (postcnt = measured_post) then
				ticks <= ticks + 1;
			else 
				if (ticks /= 0) then 
					vector <= std_logic_vector(to_signed(ticks,measure_width));
					POST_BUS_OUT <= vector(23 downto 16); --You should add a delay between prints, or use them one at time.
					POST_BUS_OUT <= vector(15 downto 8);
					POST_BUS_OUT <= vector(7 downto 0);
					ticks <= 0;
				end if;
			end if;
		end if;
	end process;
	
-- turns on dbg led during downclock
	process(slo)
	begin
		DBG <= slo;
	end process;

-- clock divider for i2c  
	process (CLK) is
	begin
		if rising_edge(CLK) then
			if divider_cnt = i2c_divider then
				i2c_clock <= not i2c_clock;
				divider_cnt <= 0;
			else 
				divider_cnt <= divider_cnt + 1;
			end if;
		end if;
	end process;

-- i2c commands streamer
	process(i2c_clock) is
	begin
		if rising_edge(i2c_clock) then
			if i2ccnt /= i2ccnt_max then
				i2ccnt <= i2ccnt + 1;
				pslo <= slo;
			else
				if pslo /= slo then
					i2ccnt <= 0;
				end if;
			end if;
			
			if ((slo = '1') and (SDA_SLOW_BITS(i2ccnt) = '1')) or ((slo = '0') and (SDA_FAST_BITS(i2ccnt) = '1')) then
				sda_out <= '1';
			else
				sda_out <= '0';
			end if;
      
			if SCL_BITS(i2ccnt) = '1' then
				scl_out <= '1';
			else
				scl_out <= '0';
			end if;
		end if;
	end process;

-- i2c send
	process (sda_out, scl_out)
	begin
		if sda_out = '0' then
			SDA <= '0';
		else
			SDA <= 'Z';
		end if;
		if scl_out = '0' then
			SCL <= '0';
		else
			SCL <= 'Z';
		end if;
	end process;

end counter;
