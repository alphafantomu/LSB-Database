# LSB-Database
LSB Database (Lua String Based Database) is a library that helps manage simple json databases that have the ".addb" extension.
Allows for simple interaction with databases, other lua engines should be able to simultaneously view and edit the database. Tested on the luvit engine.

## Usage
To start using the database:
```lua
  local LSB = require('Database'); --or Database.lua
```
How to use:
```lua
  local Shoplist = LSB:CreateDatabase('Shoplist'); --Create a database
  local GotShoplist = LSB:GetDatabase('Shoplist'); --Get a database that has already been created
  Shoplist.Carrots = 100; --Set the amount of carrots to 100
  Shoplist.Pancakes = 0; --Set the amount of pancakes to 0
  print(Shoplist == GotShoplist) --Will print true to prevent replica wrappers in the stack
  print(Shoplist.Carrots == GotShoplist.Carrots) --This will compare values, but not the variables themselves
  print(Shoplist.Carrots('GetAddress') == GotShoplist.Carrots('GetAddress')) --This will print true, since it's optimized for no replicas.
  LSB:DeleteDatabase('Shoplist'); --If the database file is closed (should be), then Shoplist.addb will be deleted.
```

To be honest, I didn't like SQL very much and I like this concise and simple like this, so I made this to make my life simpler.
