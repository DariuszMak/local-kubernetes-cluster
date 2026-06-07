Start-Process "http://localhost:10350" ; 
Start-Process "http://localhost:8003" ; 
Start-Process "http://localhost:8003/openapi.json" ; 
Start-Process "http://localhost:8003/redoc" ; 
Start-Process "http://localhost:8003/docs" ; 

.\scripts\tilt-up.ps1 ; 
