# FiveM Car Rental Script

A complete, feature-rich car rental script for FiveM servers with automatic ESX and QBCore framework detection.

## Features

- **Dual Framework Support**: Automatically detects and works with both ESX and QBCore
- **Interactive NUI Menu**: Beautiful, responsive UI for browsing and renting vehicles
- **Multiple Rental Locations**: Easily configurable rental locations with NPCs
- **Vehicle Management**: Spawn, track, and return rented vehicles
- **Payment System**: Handles rental fees and refundable deposits
- **Rental Tracking**: Prevents players from renting multiple vehicles (configurable)
- **Target System Support**: Optional integration with ox_target or qb-target
- **Clean Code**: Well-commented and optimized for performance

## Installation

1. **Download** the script and place it in your server's `resources` folder

2. **Rename** the folder to `bb-rental` (if needed)

3. **Add to server.cfg**:
   ```cfg
   ensure bb-rental
   ```

4. **Configure** the script by editing `config.lua` to match your server's needs

5. **Restart** your server or use the command:
   ```
   refresh
   start bb-rental
   ```

## Configuration

### Framework Settings
The script auto-detects ESX or QBCore, but you can manually set it in `config.lua`:
```lua
Config.Framework = 'auto' -- 'esx', 'qbcore', or 'auto'
```

### Adding Rental Locations
Edit the `Config.RentalLocations` table in `config.lua`:
```lua
{
    name = "Your Location Name",
    blip = {
        enabled = true,
        sprite = 326,
        color = 3,
        scale = 0.8,
        label = "Car Rental"
    },
    npc = {
        model = "a_m_y_business_01",
        coords = vector4(x, y, z, heading),
        scenario = "WORLD_HUMAN_CLIPBOARD"
    },
    spawnPoints = {
        vector4(x, y, z, heading),
        -- Add more spawn points
    },
    returnPoint = vector3(x, y, z)
}
```

### Adding Vehicles
Add or modify vehicles in the `Config.Vehicles` table:
```lua
{
    label = "Vehicle Name",
    model = "vehicle_spawn_name",
    price = 500,        -- Rental price
    deposit = 200,      -- Refundable deposit
    category = "economy",
    image = "https://url-to-image.png"
}
```

### Settings
Customize behavior in `Config.Settings`:
```lua
Config.Settings = {
    interactDistance = 2.5,           -- Distance to interact with NPC
    returnDistance = 5.0,             -- Distance to return vehicle
    maxRentalsPerPlayer = 1,          -- Max rentals per player (0 = unlimited)
    refundPercentage = 100,           -- Deposit refund % (100 = full refund)
    platePrefix = "RENT",             -- Rental vehicle plate prefix
    useTarget = false,                -- Enable target system
    targetResource = 'ox_target',     -- 'ox_target' or 'qb-target'
}
```

## Usage

### For Players
1. Approach a car rental NPC (look for the blip on the map)
2. Press **E** to open the rental menu
3. Browse available vehicles and select one to rent
4. The vehicle will spawn nearby and you'll be placed inside
5. To return the vehicle, drive it back to the rental location
6. Press **E** while inside the vehicle near the return point

### For Admins
Check active rentals using the admin command:
```
/checkrentals
```
(Requires admin permissions)

## Target System Integration

If you want to use ox_target or qb-target:

1. Set `Config.Settings.useTarget = true`
2. Set `Config.Settings.targetResource` to either `'ox_target'` or `'qb-target'`
3. Restart the script

## Vehicle Keys Integration

The script automatically handles vehicle keys for:
- **ESX**: Compatible with `esx_vehiclelock`
- **QBCore**: Compatible with `qb-vehiclekeys`

## Customization

### Change Colors/Styling
Edit `html/css/style.css` to customize the NUI appearance

### Modify Notifications
Edit the `Config.Lang` table in `config.lua` to change notification messages

### Add More Payment Methods
The script checks bank account first, then cash. Modify `server.lua` to change this behavior.

## Dependencies

- **Framework**: ESX or QBCore
- **Optional**: ox_target or qb-target (if using target system)

## Support

For issues or questions:
1. Check the configuration in `config.lua`
2. Review server console for error messages
3. Ensure your framework is properly installed

## File Structure

```
bb-rental/
├── client.lua          # Client-side logic
├── server.lua          # Server-side logic
├── config.lua          # Configuration file
├── fxmanifest.lua      # Resource manifest
├── README.md           # This file
└── html/
    ├── index.html      # NUI HTML
    ├── css/
    │   └── style.css   # NUI Styling
    └── js/
        └── script.js   # NUI JavaScript
```

## Credits

Created for FiveM QBCore servers
Compatible with ESX and QBCore frameworks

## License

Free to use and modify for your FiveM server
