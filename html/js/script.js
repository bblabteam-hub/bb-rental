// Main event listener for NUI messages
window.addEventListener('message', function(event) {
    const data = event.data;

    switch(data.action) {
        case 'openMenu':
            openMenu(data.vehicles, data.hasRental);
            break;
        case 'closeMenu':
            closeMenu();
            break;
    }
});

// Open the rental menu
function openMenu(vehicles, hasRental) {
    $('#container').removeClass('hidden');

    // Show/hide current rental banner
    if (hasRental) {
        $('#currentRental').removeClass('hidden');
    } else {
        $('#currentRental').addClass('hidden');
    }

    // Populate vehicles
    populateVehicles(vehicles);
}

// Close the menu
function closeMenu() {
    $('#container').addClass('hidden');

    // Send close message to client
    $.post('https://bb-rental/closeMenu', JSON.stringify({}));
}

// Populate vehicles in the grid
function populateVehicles(vehicles) {
    const vehiclesList = $('#vehiclesList');
    vehiclesList.empty();

    vehicles.forEach((vehicle, index) => {
        const totalCost = vehicle.price + vehicle.deposit;

        const vehicleCard = `
            <div class="vehicle-card" onclick="rentVehicle(${index})">
                <div class="vehicle-image">
                    <img src="${vehicle.image}" alt="${vehicle.label}" onerror="this.src='https://via.placeholder.com/300x180?text=${vehicle.label}'">
                    <span class="category-badge">${vehicle.category}</span>
                </div>
                <div class="vehicle-info">
                    <div class="vehicle-name">${vehicle.label}</div>
                    <div class="price-info">
                        <div class="price-item">
                            <span class="price-label">Rental Fee</span>
                            <span class="price-value">$${formatNumber(vehicle.price)}</span>
                        </div>
                        <div class="price-item">
                            <span class="price-label">Deposit</span>
                            <span class="price-value">$${formatNumber(vehicle.deposit)}</span>
                        </div>
                    </div>
                    <button class="rent-btn">Rent for $${formatNumber(totalCost)}</button>
                </div>
            </div>
        `;

        vehiclesList.append(vehicleCard);
    });
}

// Rent a vehicle
function rentVehicle(index) {
    // Close the menu immediately
    closeMenu();

    // Send rent request
    $.post('https://bb-rental/rentVehicle', JSON.stringify({
        index: index + 1 // Lua arrays start at 1
    }));
}

// Return the current rented vehicle
function returnVehicle() {
    $.post('https://bb-rental/returnVehicle', JSON.stringify({}));
}

// Format numbers with commas
function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Close menu on ESC key
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeMenu();
    }
});

// Prevent right click
document.addEventListener('contextmenu', function(event) {
    event.preventDefault();
});
