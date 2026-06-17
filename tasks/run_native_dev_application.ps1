Start-Process uv -ArgumentList "run", "python", "src\main.py" ; 
Start-Process uv -ArgumentList "run", "python", "src2\main.py" ; 

Start-Process "http://localhost:8001" ; 
Start-Process "http://localhost:8001/openapi.json" ; 
Start-Process "http://localhost:8001/redoc" ; 
Start-Process "http://localhost:8001/docs" ; 

Start-Process "http://localhost:8002" ; 
Start-Process "http://localhost:8002/openapi.json" ; 
Start-Process "http://localhost:8002/redoc" ; 
Start-Process "http://localhost:8002/docs" ; 
