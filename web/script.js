const app = document.getElementById("app");
const container = document.getElementById("vehicleContainer");

const renameModal = document.getElementById("renameModal");
const renameInput = document.getElementById("renameInput");
const saveRename = document.getElementById("saveRename");
const cancelRename = document.getElementById("cancelRename");

let isOpen = false;
let selectedVehicle = null;
let currentGarageIsJob = false;

function openGarage(vehicles, isJobGarage = false) {
    if (isOpen) return;
    isOpen = true;

    currentGarageIsJob = isJobGarage;

    app.classList.remove("hidden");

    setTimeout(() => {
        app.classList.add("show");
    }, 10);

    loadVehicles(vehicles);
}

function closeGarage() {
    if (!isOpen) return;
    isOpen = false;

    app.classList.remove("show");

    setTimeout(() => {
        app.classList.add("hidden");
    }, 200);

    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({})
    });
}

window.addEventListener("message", (event) => {
    const { action, vehicles, isJobGarage } = event.data || {};

    switch (action) {
        case "open":
            openGarage(vehicles || [], isJobGarage || false);
            break;

        case "close":
            closeGarage();
            break;
    }
});

function loadVehicles(vehicles = []) {
    container.innerHTML = "";

    vehicles.forEach((v, i) => {

        if (currentGarageIsJob && !v.isJobVehicle) {
            return;
        }

        const card = document.createElement("div");

        card.className = "card";
        card.style.animationDelay = `${i * 0.05}s`;

        card.innerHTML = `
            <p class="vehicletitle">${v.name}</p>

            <div class="stats">
                <div>
                    <span>NUMMERPLADE</span>
                    <p>${v.plate}</p>
                </div>

                <div>
                    <span>TANK</span>
                    <p>${v.fuel}%</p>
                </div>
            </div>

            <div class="button-group">
                <button class="btn ${v.out ? "in" : "out"}">
                    ${v.out ? "Allerede ude" : "Tag ud"}
                </button>

                ${
                    currentGarageIsJob
                        ? ""
                        : `
                        <button class="btn rename">
                            Ændre navn
                        </button>
                    `
                }
            </div>
        `;

        const outBtn = card.querySelector(".out");
        const renameBtn = card.querySelector(".rename");

        if (!v.out && outBtn) {
            outBtn.addEventListener("click", () => {
                outBtn.disabled = true;

                fetch(`https://${GetParentResourceName()}/takeOutVehicle`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    body: JSON.stringify({
                        plate: v.plate,
                        name: v.name,
                        isJobVehicle: v.isJobVehicle || false
                    })
                });
            });
        }

        if (renameBtn) {
            renameBtn.addEventListener("click", () => {
                selectedVehicle = v;

                renameInput.value = v.name || "";

                renameModal.classList.remove("hidden");

                setTimeout(() => {
                    renameInput.focus();
                }, 10);
            });
        }

        container.appendChild(card);
    });
}

saveRename.addEventListener("click", () => {
    const newName = renameInput.value.trim();

    if (!newName || !selectedVehicle) return;

    fetch(`https://${GetParentResourceName()}/renameVehicle`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            plate: selectedVehicle.plate,
            newName: newName
        })
    });

    const cards = document.querySelectorAll(".card");

    cards.forEach(card => {
        const title = card.querySelector(".vehicletitle");

        if (title && title.textContent === selectedVehicle.name) {
            title.textContent = newName;
        }
    });

    selectedVehicle.name = newName;

    renameModal.classList.add("hidden");

    selectedVehicle = null;
});

cancelRename.addEventListener("click", () => {
    renameModal.classList.add("hidden");
    selectedVehicle = null;
});

window.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
        if (!renameModal.classList.contains("hidden")) {
            renameModal.classList.add("hidden");
            selectedVehicle = null;
        } else {
            closeGarage();
        }
    }
});

container.addEventListener("wheel", (e) => {
    container.scrollTop += e.deltaY;
});