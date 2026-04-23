--[[
                                                                                                                                                                       
                                                                                                                                                                       
               AAA               DDDDDDDDDDDDD      VVVVVVVV           VVVVVVVVEEEEEEEEEEEEEEEEEEEEEENNNNNNNN        NNNNNNNNTTTTTTTTTTTTTTTTTTTTTTT   SSSSSSSSSSSSSSS 
              A:::A              D::::::::::::DDD   V::::::V           V::::::VE::::::::::::::::::::EN:::::::N       N::::::NT:::::::::::::::::::::T SS:::::::::::::::S
             A:::::A             D:::::::::::::::DD V::::::V           V::::::VE::::::::::::::::::::EN::::::::N      N::::::NT:::::::::::::::::::::TS:::::SSSSSS::::::S
            A:::::::A            DDD:::::DDDDD:::::DV::::::V           V::::::VEE::::::EEEEEEEEE::::EN:::::::::N     N::::::NT:::::TT:::::::TT:::::TS:::::S     SSSSSSS
           A:::::::::A             D:::::D    D:::::DV:::::V           V:::::V   E:::::E       EEEEEEN::::::::::N    N::::::NTTTTTT  T:::::T  TTTTTTS:::::S            
          A:::::A:::::A            D:::::D     D:::::DV:::::V         V:::::V    E:::::E             N:::::::::::N   N::::::N        T:::::T        S:::::S            
         A:::::A A:::::A           D:::::D     D:::::D V:::::V       V:::::V     E::::::EEEEEEEEEE   N:::::::N::::N  N::::::N        T:::::T         S::::SSSS         
        A:::::A   A:::::A          D:::::D     D:::::D  V:::::V     V:::::V      E:::::::::::::::E   N::::::N N::::N N::::::N        T:::::T          SS::::::SSSSS    
       A:::::A     A:::::A         D:::::D     D:::::D   V:::::V   V:::::V       E:::::::::::::::E   N::::::N  N::::N:::::::N        T:::::T            SSS::::::::SS  
      A:::::AAAAAAAAA:::::A        D:::::D     D:::::D    V:::::V V:::::V        E::::::EEEEEEEEEE   N::::::N   N:::::::::::N        T:::::T               SSSSSS::::S 
     A:::::::::::::::::::::A       D:::::D     D:::::D     V:::::V:::::V         E:::::E             N::::::N    N::::::::::N        T:::::T                    S:::::S
    A:::::AAAAAAAAAAAAA:::::A      D:::::D    D:::::D       V:::::::::V          E:::::E       EEEEEEN::::::N     N:::::::::N        T:::::T                    S:::::S
   A:::::A             A:::::A   DDD:::::DDDDD:::::D         V:::::::V         EE::::::EEEEEEEE:::::EN::::::N      N::::::::N      TT:::::::TT      SSSSSSS     S:::::S
  A:::::A               A:::::A  D:::::::::::::::DD           V:::::V          E::::::::::::::::::::EN::::::N       N:::::::N      T:::::::::T      S::::::SSSSSS:::::S
 A:::::A                 A:::::A D::::::::::::DDD              V:::V           E::::::::::::::::::::EN::::::N        N::::::N      T:::::::::T      S:::::::::::::::SS 
AAAAAAA                   AAAAAAADDDDDDDDDDDDD                  VVV            EEEEEEEEEEEEEEEEEEEEEENNNNNNNN         NNNNNNN      TTTTTTTTTTT       SSSSSSSSSSSSSSS   
                                                                                                                                                                       
                                                                                                                                                                       
                                                                                                                                                                       
                                                                                                                                                                       
                                                                                                                                                                       
                                                                                                                                                                       
                                                                                                                                                                       
]]

return {
	animator = require("./advents/animator"); -- A 
	debris = require("./advents/debris"); -- D
	vector = require("./advents/vector"); -- V
	easing = require("./advents/easing"); -- E
	effects = require("./advents/effects"); -- E
	num = require("./advents/num"); -- N
	thread = require("./advents/thread"); -- T
	spring = require("./advents/spring"); -- S
	sounds = require("./advents/sounds"); -- S
}