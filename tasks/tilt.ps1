Start-Process "http://localhost:10350" ; 

Start-Process "http://localhost:8003" ; 
Start-Process "http://localhost:8003/openapi.json" ; 
Start-Process "http://localhost:8003/redoc" ; 
Start-Process "http://localhost:8003/docs" ; 

Start-Process "http://localhost:8004" ; 
Start-Process "http://localhost:8004/openapi.json" ; 
Start-Process "http://localhost:8004/redoc" ; 
Start-Process "http://localhost:8004/docs" ; 

.\scripts\tilt-up.ps1 ; 
