-- Coded by DrSchottky. Based on Alibaba's code.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.STD_LOGIC_UNSIGNED.all;

entity main is
  
port (
	DBG : out STD_LOGIC := '0';
	POSTBIT : in STD_LOGIC;
	CLK : in STD_LOGIC;
	CPU_RESET : inout STD_LOGIC := 'Z';
	PLL_BYPASS : out STD_LOGIC := '0';
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
signal postcnt : integer range 0 to postcnt_max := 0;
signal ticks : integer range 0 to 2**measure_width -1 := 0;
signal vector: STD_LOGIC_VECTOR((measure_width -1) downto 0) := std_logic_vector(to_signed(0,measure_width));
signal slo : STD_LOGIC := '0';

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

--	downclock
	process(slo)
	begin
		PLL_BYPASS <= slo;
	end process;
end counter;
