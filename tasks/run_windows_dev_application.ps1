Start-Process uv -ArgumentList "run", "python", "src\main.py" ; 
Start-Process "http://localhost:8001" ; 
Start-Process "http://localhost:8001/openapi.json" ; 
Start-Process "http://localhost:8001/redoc" ; 
Start-Process "http://localhost:8001/docs" ; 