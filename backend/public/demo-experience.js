(() => {
  const circumference = 264;
  const gaugePosition = (value, low, high, percent = false) => {
    const width = high - low;
    let minimum = low - width / 2;
    let maximum = high + width / 2;
    if (percent) {
      minimum = Math.max(0, minimum);
      maximum = Math.min(100, maximum);
    }
    const span = Math.max(0.000001, maximum - minimum);
    const state = value == null ? "No reading" : value < low ? "Below target" : value > high ? "Above target" : "In range";
    return {
      fraction: value == null ? 0.5 : Math.max(0, Math.min(1, (value - minimum) / span)),
      bandStart: Math.max(0, Math.min(1, (low - minimum) / span)),
      bandEnd: Math.max(0, Math.min(1, (high - minimum) / span)),
      state,
    };
  };
  const niceTicks = (minimum, maximum) => {
    if (!Number.isFinite(minimum) || !Number.isFinite(maximum)) return [];
    if (maximum <= minimum) { minimum -= 1; maximum += 1; }
    const magnitude = 10 ** Math.floor(Math.log10((maximum - minimum) / 4));
    const candidates = [1, 2, 2.5, 5, 10].map((step) => step * magnitude);
    const selected = candidates.find((step) => {
      const count = Math.ceil(maximum / step) - Math.floor(minimum / step) + 1;
      return count >= 4 && count <= 6;
    }) || candidates[candidates.length - 1];
    const first = Math.floor(minimum / selected);
    const last = Math.ceil(maximum / selected);
    return Array.from({ length: last - first + 1 }, (_, index) => (first + index) * selected);
  };
  const readingAgeCaption = (age) => age > 60 ? "Simulated readings are paused" : "Simulated · updated " + age + " s ago";
  const partA = [
    { title: "Explore Instant Demo", where: "Overview", hint: "Explain that readings are simulated and shared without an account." },
    { title: "Compare trend ranges and export readings", where: "Trends", hint: "Show 24 hours, 1 month and 3 months, then export." },
    { title: "Switch crops and compare target bands", where: "Overview", hint: "Choose another crop and compare its target band." },
    { title: "Review simulated alert history", where: "Alerts", hint: "Point out that SMS is not sent." },
  ];
  const originalRender = window.render;
  const originalRefresh = window.refresh;
  const originalLoadSites = window.loadSites;
  const originalLoadAlerts = window.loadAlerts;
  const originalLoadTotp = window.loadTotp;
  let readingCreatedAt = null;
  let expiryAt = null;

  function button(label, action, primary = false) {
    const element = document.createElement("button");
    element.type = "button";
    element.textContent = label;
    if (primary) element.className = "primary";
    element.addEventListener("click", action);
    return element;
  }

  function card(title, message, actionLabel, action) {
    const element = document.createElement("section");
    element.className = "card py-mode-card";
    const heading = document.createElement("h2");
    heading.textContent = title;
    const text = document.createElement("p");
    text.className = "muted";
    text.textContent = message;
    element.append(heading, text);
    if (actionLabel) element.append(button(actionLabel, action, true));
    return element;
  }

  function showProfileDialog() {
    return new Promise((resolve) => {
      const dialog = document.createElement("dialog");
      dialog.className = "py-dialog";
      const heading = document.createElement("h2");
      heading.textContent = "Start Guided Demo";
      const hint = document.createElement("p");
      hint.textContent = "Showcase starts with example locations, linked sensors and alert history. Walkthrough starts with an unlinked sensor.";
      const select = document.createElement("select");
      select.setAttribute("aria-label", "Guided Demo profile");
      for (const [value, label] of [["showcase", "Showcase · recommended"], ["walkthrough", "Walkthrough · start empty"]]) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = label;
        select.append(option);
      }
      const actions = document.createElement("div");
      actions.className = "py-actions";
      const cancel = button("Cancel", () => { dialog.close(); resolve(null); });
      const start = button("Start Showcase", () => { dialog.close(); resolve(select.value); }, true);
      select.addEventListener("change", () => {
        start.textContent = select.value === "showcase" ? "Start Showcase" : "Start Walkthrough";
      });
      actions.append(cancel, start);
      dialog.append(heading, hint, select, actions);
      document.body.append(dialog);
      dialog.addEventListener("close", () => { dialog.remove(); resolve(null); }, { once: true });
      dialog.showModal();
    });
  }

  function passwordDialog(password) {
    return new Promise((resolve) => {
      const dialog = document.createElement("dialog");
      dialog.className = "py-dialog";
      const heading = document.createElement("h2");
      heading.textContent = "Save your Guided Demo password";
      const text = document.createElement("p");
      text.textContent = "This generated password is shown once. Keep it available for authenticator setup and phone pairing.";
      const secret = document.createElement("p");
      secret.className = "py-demo-password";
      secret.textContent = password;
      const actions = document.createElement("div");
      actions.className = "py-actions";
      const copy = button("Copy password", async () => {
        try {
          await navigator.clipboard.writeText(password);
          copy.textContent = "Copied";
        } catch {
          const status = document.createElement("p");
          status.className = "muted";
          status.textContent = "Clipboard access is unavailable. Select and copy the password above.";
          secret.after(status);
        }
      });
      const close = button("Continue", () => dialog.close(), true);
      actions.append(copy, close);
      dialog.append(heading, text, secret, actions);
      document.body.append(dialog);
      dialog.addEventListener("close", () => { dialog.remove(); resolve(); }, { once: true });
      dialog.showModal();
    });
  }

  window.startGuided = async function startGuided() {
    const profile = await showProfileDialog();
    if (!profile) return;
    try {
      const result = await api("/demo/start", { method: "POST", body: JSON.stringify({ profile }) });
      token = result.token;
      mode = "guided";
      page = "Overview";
      startEvents();
      render();
      await refresh();
      await passwordDialog(result.demoPassword);
      banner("Demo session. Data is simulated and will be deleted.");
    } catch (error) {
      banner(error.message, true);
    }
  };

  window.loadTotp = async function loadTotpForMode() {
    if (mode === "instant") return;
    return originalLoadTotp?.();
  };

  window.loadSites = async function loadSitesForMode() {
    if (mode === "instant") {
      const summary = $("#sensor-summary");
      const host = $("#sites");
      if (summary) summary.textContent = "Personal storage locations and sensor management need an account.";
      if (host) host.replaceChildren();
      return;
    }
    return originalLoadSites?.();
  };

  window.loadAlerts = async function loadAlertsWithIntentionalEmptyState() {
    await originalLoadAlerts?.();
    const host = $("#alerts");
    if (!host) return;
    if (!host.children.length) {
      const empty = document.createElement("div");
      empty.className = "card py-alert-empty";
      const icon = document.createElement("span");
      icon.setAttribute("aria-hidden", "true");
      icon.textContent = "✓";
      const title = document.createElement("h2");
      title.textContent = "No alerts yet";
      const text = document.createElement("p");
      text.className = "muted";
      text.textContent = "Simulated readings are within the selected crop's target band.";
      empty.append(icon, title, text);
      host.append(empty);
    }
    if (mode === "instant") {
      for (const oldButton of host.querySelectorAll("button[data-action='review-alert']")) {
        const replacement = button("Start Guided Demo to review", () => window.startGuided());
        oldButton.replaceWith(replacement);
      }
    }
  };

  function addGuideButton() {
    if (!["instant", "guided"].includes(mode)) {
      $("#demo-guide-button")?.remove();
      return;
    }
    if (!$("#app") || $("#demo-guide-button")) return;
    const trigger = button("Demo guide", openGuide);
    trigger.id = "demo-guide-button";
    document.body.append(trigger);
  }

  async function openGuide() {
    const old = $("#demo-guide-drawer");
    if (old) { old.remove(); return; }
    let serverSteps = [];
    if (mode === "guided") {
      try { serverSteps = (await api("/demo/checklist")).steps || []; }
      catch (error) { banner(error.message, true); return; }
    }
    const drawer = document.createElement("aside");
    drawer.id = "demo-guide-drawer";
    drawer.className = "py-guide-drawer";
    const header = document.createElement("div");
    header.className = "py-guide-header";
    const title = document.createElement("h2");
    title.textContent = "Demo guide";
    header.append(title, button("Close", () => drawer.remove()));
    const next = mode === "guided"
      ? serverSteps.find((step) => step.part === "B" && !step.completed)
      : partA[0];
    const nextStep = document.createElement("p");
    nextStep.className = "py-guide-next";
    nextStep.textContent = next ? "Next step: " + next.title : "Guide complete.";
    drawer.append(header, nextStep);
    const steps = mode === "guided" ? [...partA, ...serverSteps.filter((step) => step.part === "B")] : partA;
    for (const step of steps) {
      const row = document.createElement("article");
      row.className = "py-guide-step";
      const label = document.createElement("b");
      label.textContent = (step.part || (partA.includes(step) ? "A" : "B")) + " · " + step.title;
      const hint = document.createElement("p");
      hint.className = "muted";
      hint.textContent = step.hint || "";
      const result = document.createElement("p");
      result.className = "muted";
      result.textContent = step.completed ? "Done" : "Expected: " + (step.expected || step.hint || "Follow the presenter prompt.");
      const go = button("Take me there", () => {
        page = step.where || "Settings";
        drawer.remove();
        render();
        refresh();
      });
      row.append(label, hint, result);
      if (mode === "guided" && step.part === "B" && !step.auto) {
        row.append(button(step.completed ? "Mark incomplete" : "Mark complete", async () => {
          try {
            await api("/demo/checklist/" + step.step, {
              method: "PATCH",
              body: JSON.stringify({ completed: !step.completed }),
            });
            drawer.remove();
            await openGuide();
          } catch (error) {
            banner(error.message, true);
          }
        }));
      }
      row.append(go);
      drawer.append(row);
    }
    const note = document.createElement("p");
    note.className = "muted";
    note.textContent = "QR failure examples: wait for expiry, scan one code twice, or enter three incorrect match numbers.";
    drawer.append(note);
    document.body.append(drawer);
  }

  function maskedAddress(address) {
    const value = String(address || "");
    try {
      const parsed = new URL(value.includes("://") ? value : "http://" + value);
      const host = parsed.hostname;
      if (host === "localhost" || host === "::1" || host.startsWith("127.")) return "Not detected";
      const hidden = /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host)
        ? host.replace(/\.\d{1,3}$/, ".•••")
        : (host.length > 4 ? host.slice(0, 4) + "•••" : "Not detected");
      return hidden === "Not detected" ? hidden : parsed.protocol + "//" + hidden + (parsed.port ? ":" + parsed.port : "");
    } catch {
      return "Not detected";
    }
  }
  window.PeoYameDemoMath = Object.freeze({ gaugePosition, niceTicks, maskedAddress, readingAgeCaption });

  function renderGauge(host, title, rawValue, low, high, unit) {
    const value = rawValue != null && Number.isFinite(Number(rawValue)) ? Number(rawValue) : null;
    const position = gaugePosition(value, low, high, unit === "%");
    const color = position.state === "In range" ? "#1f7a52" : "#b3382c";
    let ring = host.querySelector(".ring");
    if (!host.querySelector(".py-gauge-target")) {
      host.replaceChildren();
      ring = document.createElement("div");
      ring.className = "ring";
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 100 100");
      svg.setAttribute("aria-hidden", "true");
      for (const className of ["ring-track", "ring-value", "py-gauge-target"]) {
        const circle = document.createElementNS("http://www.w3.org/2000/svg", "circle");
        circle.setAttribute("cx", "50");
        circle.setAttribute("cy", "50");
        circle.setAttribute("r", "42");
        circle.setAttribute("class", className);
        svg.append(circle);
      }
      const marker = document.createElementNS("http://www.w3.org/2000/svg", "circle");
      marker.setAttribute("cx", "92");
      marker.setAttribute("cy", "50");
      marker.setAttribute("r", "4.5");
      marker.setAttribute("class", "py-gauge-marker");
      svg.append(marker);
      ring.append(svg);
      const valueLabel = document.createElement("div");
      valueLabel.className = "value py-gauge-value";
      ring.append(valueLabel);
      const label = document.createElement("b");
      label.className = "py-gauge-title";
      host.append(ring, label);
      const stateLabel = document.createElement("div");
      stateLabel.className = "py-gauge-state";
      host.append(stateLabel);
      const targetLabel = document.createElement("div");
      targetLabel.className = "ticks py-gauge-band";
      host.append(targetLabel);
    }
    const target = host.querySelector(".py-gauge-target");
    target.setAttribute("stroke-dasharray", `${circumference * (position.bandEnd - position.bandStart)} ${circumference}`);
    target.setAttribute("stroke-dashoffset", String(-circumference * position.bandStart));
    target.setAttribute("stroke", "#1f7a52");
    const arc = host.querySelector(".ring-value");
    arc.setAttribute("stroke-dasharray", String(circumference));
    arc.setAttribute("stroke-dashoffset", String(circumference * (1 - position.fraction)));
    arc.setAttribute("stroke", color);
    const marker = host.querySelector(".py-gauge-marker");
    marker.setAttribute("transform", `rotate(${position.fraction * 360} 50 50)`);
    marker.setAttribute("fill", color);
    host.querySelector(".py-gauge-value").textContent = value == null ? "—" : (unit === "%" ? value.toFixed(0) + "\u00a0%" : value.toFixed(1) + "\u00a0°C");
    host.querySelector(".py-gauge-value").setAttribute("data-state", position.state);
    host.querySelector(".py-gauge-title").textContent = title;
    host.querySelector(".py-gauge-state").textContent = position.state;
    host.querySelector(".py-gauge-state").setAttribute("data-state", position.state);
    host.querySelector(".py-gauge-band").textContent = `Target ${low}–${high} ${unit}`;
    host.setAttribute("role", "img");
    host.setAttribute("aria-label", value == null
      ? `${title}: no reading. Target ${low} to ${high} ${unit}.`
      : `${title} ${unit === "%" ? value.toFixed(0) + " %" : value.toFixed(1) + " °C"}, ${position.state.toLowerCase()}, target ${low} to ${high} ${unit}.`);
  }

  function ensureHeader() {
    const host = document.querySelector("header .head");
    if (!host) return;
    let chip = $("#demo-mode-chip");
    if (mode === "instant" || mode === "guided") {
      if (!chip) {
        chip = document.createElement("span");
        chip.id = "demo-mode-chip";
        chip.className = "py-demo-chip";
        host.insertBefore(chip, $("#sync"));
      }
      chip.textContent = mode === "guided" ? "Demo mode is on" : "Shared demo profile · simulated readings";
    } else {
      chip?.remove();
    }
    if (mode === "guided" && expiryAt) {
      let timer = $("#demo-expiry");
      if (!timer) {
        timer = document.createElement("span");
        timer.id = "demo-expiry";
        timer.className = "py-expiry";
        host.append(timer);
      }
      const seconds = Math.max(0, Math.ceil((expiryAt - Date.now()) / 1000));
      timer.textContent = "Demo expires in " + Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
      timer.classList.toggle("warning", seconds <= 600);
      const state = seconds === 0 ? "expired" : seconds <= 600 ? "warning" : "normal";
      let guidance = $("#demo-expiry-guidance");
      if (state === "normal") {
        guidance?.remove();
      } else if (!guidance || guidance.dataset.state !== state) {
        if (!guidance) {
          guidance = document.createElement("div");
          guidance.id = "demo-expiry-guidance";
          guidance.className = "notice banner py-expiry-guidance";
          guidance.setAttribute("role", "status");
          $("#banner")?.before(guidance);
        }
        guidance.dataset.state = state;
        guidance.replaceChildren(document.createTextNode(
          state === "expired"
            ? "Guided Demo session expired. Return to sign-in and start another demo."
            : "Guided Demo expires soon. Reset and start again before presenting.",
        ));
        if (state === "warning") {
          guidance.append(button("Reset and start again", () => window.resetDemo()));
        }
      }
    } else {
      $("#demo-expiry")?.remove();
      $("#demo-expiry-guidance")?.remove();
    }
  }

  function updateReadingAge() {
    const host = $("#reading-age");
    if (!host || !readingCreatedAt) return;
    const age = Math.max(0, Math.floor((Date.now() - readingCreatedAt) / 1000));
    host.replaceChildren();
    const text = document.createElement("span");
    text.textContent = readingAgeCaption(age);
    host.append(text);
    if (age > 60 && mode === "guided") {
      host.append(button("Start simulated readings", () => toggleDemoSimulation()));
    }
    host.classList.toggle("paused", age > 60);
    ensureHeader();
  }

  function addOverviewContent(status) {
    const host = $("#screen");
    const statusNode = $("#status");
    if (statusNode && status?.targetBands) {
      statusNode.setAttribute("aria-label", status.statusLabel || "Crop status");
      statusNode.classList.toggle("outside", status.statusLabel === "Outside target band");
      const notice = $("#banner .notice");
      if (notice) notice.classList.toggle("banner", status.statusLabel === "Outside target band");
      const risk = $("#estimate-risk");
      if (risk && status.estimate?.risk) {
        risk.classList.remove("risk-low", "risk-medium", "risk-high");
        risk.classList.add("risk-" + String(status.estimate.risk).toLowerCase());
      }
      const cropLabel = host.querySelector("#crop-context") || document.createElement("span");
      cropLabel.id = "crop-context";
      cropLabel.className = "muted py-crop-context";
      cropLabel.textContent = status.crop + " · target " +
        status.targetBands.temperatureC.join("–") + " °C, " +
        status.targetBands.humidityPercent.join("–") + " %";
      statusNode.parentElement?.append(cropLabel);
      const select = $("#crop");
      if (select && [...select.options].some((option) => option.value === status.crop)) select.value = status.crop;
    }
    const gaugeGrid = host?.querySelector(".ggrid");
    if (gaugeGrid) {
      const gauges = gaugeGrid.querySelectorAll(".gauge");
      const temperature = status?.reading?.temperature;
      const humidity = status?.reading?.humidity;
      if (gauges.length >= 2 && status?.targetBands) {
        renderGauge(gauges[0], "Temperature", temperature, status.targetBands.temperatureC[0], status.targetBands.temperatureC[1], "°C");
        renderGauge(gauges[1], "Humidity", humidity, status.targetBands.humidityPercent[0], status.targetBands.humidityPercent[1], "%");
      }
      let age = $("#reading-age");
      if (!age) {
        age = document.createElement("div");
        age.id = "reading-age";
        age.className = "py-reading-age muted";
        gaugeGrid.after(age);
      }
    }
    const estimate = $("#estimate-card");
    if (status?.stale && estimate) {
      estimate.hidden = false;
      const value = $("#estimate");
      if (value) value.textContent = "Estimate hidden: the latest reading is more than 15 minutes old.";
      const action = estimate.querySelector("[data-action='estimate-help']");
      if (mode === "guided" && !estimate.querySelector("[data-action='start-readings']")) {
        const start = button("Start simulated readings", () => toggleDemoSimulation(), true);
        start.dataset.action = "start-readings";
        action?.before(start);
      }
    } else if (status?.estimate) {
      estimate.hidden = false;
      if (status.estimate.rangeWeeks?.[0] === 0) $("#estimate").textContent = "Less than 1 week";
    }
  }

  function prepareSettings() {
    const grid = document.querySelector(".py-settings-grid");
    if (!grid) return;
    const demoCard = $("#demo-card");
    if (mode === "instant") {
      const dataCard = grid.querySelector(".py-settings-card");
      grid.replaceChildren(dataCard, demoCard);
      grid.append(card("Account features need Guided Demo or an account",
        "Profile, security, QR pairing and storage management require a signed-in account.",
        "Start Guided Demo", () => window.startGuided()));
      const exit = button("Leave Demo mode", () => {
        stopEvents();
        mode = "instant";
        page = "Overview";
        $("#app").classList.add("hide");
        $("#gate").classList.remove("hide");
      });
      grid.append(exit);
    }
    if (demoCard && mode !== "farmer") {
      demoCard.hidden = false;
      if (!guidedDemoEnabled) {
        demoCard.replaceChildren(card("Guided Demo is off",
          "On the computer, open the Peo Yame tray menu and choose Demo mode."));
      } else if (mode === "instant") {
        demoCard.replaceChildren(card("Guided Demo",
          "Start a temporary account to demonstrate sensor, alert, authenticator and QR workflows.",
          "Start Guided Demo", () => window.startGuided()));
      } else {
        addSimulationControls(demoCard);
        addPreflight(demoCard);
      }
    }
    const hint = document.querySelector(".py-settings-card .muted");
    if (hint?.textContent.includes("Password re-check")) hint.classList.add("py-password-hint");
  }

  function addSimulationControls(host) {
    let controls = $("#demo-enhanced-controls");
    if (!controls) {
      controls = document.createElement("div");
      controls.id = "demo-enhanced-controls";
      controls.className = "py-simulation-controls";
      host.append(controls);
    }
    controls.replaceChildren();
    api("/demo/simulation").then((state) => {
      const label = document.createElement("label");
      label.className = "py-switch";
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = state.autoAlerts !== false;
      checkbox.addEventListener("change", async () => {
        checkbox.disabled = true;
        try {
          await api("/demo/simulation/settings", { method: "POST", body: JSON.stringify({ autoAlerts: checkbox.checked }) });
        } catch (error) {
          checkbox.checked = !checkbox.checked;
          banner(error.message, true);
        } finally {
          checkbox.disabled = false;
        }
      });
      const caption = document.createElement("span");
      caption.textContent = "Automatic breach alerts";
      label.append(checkbox, caption);
      controls.append(label,
        button("Return to in-band", async () => {
          try { await api("/demo/simulation/in-band", { method: "POST", body: "{}" }); await refresh(); }
          catch (error) { banner(error.message, true); }
        }));
    }).catch((error) => banner(error.message, true));
  }

  async function addPreflight(host) {
    if ($("#demo-preflight")) return;
    const panel = document.createElement("section");
    panel.id = "demo-preflight";
    panel.className = "py-preflight";
    const heading = document.createElement("h3");
    heading.textContent = "Before you present";
    const state = document.createElement("p");
    state.textContent = "Demo mode is on · Checking sessions and network address…";
    const network = document.createElement("p");
    network.className = "muted";
    const tips = document.createElement("p");
    tips.className = "muted";
    tips.textContent = "Use the same Wi-Fi on both devices. Allow the Windows Firewall prompt. Plain HTTP is for a controlled network only. Phone reachability: Not verified from the backend.";
    panel.append(heading, state, network, tips);
    host.append(panel);
    try {
      const [sessions, backend] = await Promise.all([api("/account/sessions"), api("/backend/qr")]);
      state.textContent = "Demo mode is on · " + (demoSimulationActive ? "simulated readings are running" : "simulated readings are paused") +
        " · " + sessions.length + " active session(s).";
      let visible = false;
      network.textContent = "Detected LAN address: " + maskedAddress(backend.baseUrl);
      panel.append(button("Show LAN address", () => {
        visible = !visible;
        network.textContent = "Detected LAN address: " + (visible ? backend.baseUrl : maskedAddress(backend.baseUrl));
      }));
    } catch (error) {
      state.textContent = "Demo mode is on · Session/address details unavailable.";
      banner(error.message, true);
    }
  }

  window.render = function renderWithDemoExperience(...args) {
    const result = originalRender?.(...args);
    const demoLabel = document.querySelector("[data-action='start-instant']");
    if (demoLabel) demoLabel.textContent = "Demo mode";
    if (mode === "instant" && page === "My Crops") {
      const host = $("#screen");
      host.replaceChildren(host.querySelector("h1"));
      host.append(card("My Crops needs an account",
        "Instant Demo is read-only. Add storage locations, link sensors and manage crops in Guided Demo.",
        "Start Guided Demo to try this", () => window.startGuided()));
    }
    if (mode === "instant" && page === "Alerts") {
      for (const oldButton of document.querySelectorAll("#alerts button")) oldButton.replaceWith(
        button("Start Guided Demo to review", () => window.startGuided()));
    }
    if (page === "Settings") prepareSettings();
    ensureHeader();
    addGuideButton();
    return result;
  };

  window.refresh = async function refreshWithDemoExperience(...args) {
    const result = await originalRefresh?.(...args);
    const gateNote = $("#gate-notice");
    if (gateNote) gateNote.textContent = !guidedDemoEnabled
      ? "Guided Demo is off. On the computer, open the Peo Yame tray menu and choose Demo mode."
      : "";
    if (mode !== "farmer") {
      try {
        const status = await api("/status?crop=" + encodeURIComponent(crop));
        if (status.isDemo) mode = "guided";
        readingCreatedAt = status.reading?.createdAt ? Date.parse(status.reading.createdAt) : null;
        expiryAt = status.sessionExpiresAt ? Date.parse(status.sessionExpiresAt) : null;
        if (status.crop) crop = status.crop;
        if (page === "Overview") addOverviewContent(status);
        ensureHeader();
        updateReadingAge();
        if (page === "Settings") prepareSettings();
      } catch (error) {
        if (mode === "guided") banner(error.message, true);
      }
    }
    return result;
  };

  window.refreshTrends = async function refreshTrendsWithCrop() {
    try {
      const [data, status] = await Promise.all([
        api("/readings/trends?range=" + encodeURIComponent(trendRange) + "&crop=" + encodeURIComponent(crop)),
        api("/status?crop=" + encodeURIComponent(crop)),
      ]);
      for (const control of document.querySelectorAll("[data-action='trend-range']")) {
        control.setAttribute("aria-pressed", String(control.dataset.range === trendRange));
      }
      const help = document.querySelector(".trend-controls + .muted");
      if (help && mode === "instant") help.textContent = "Exports include the shared simulated readings.";
      const controls = document.querySelector(".trend-controls");
      if (controls) {
        const exports = [...controls.querySelectorAll("[data-action='download-readings']")];
        exports.forEach((item) => item.classList.add("trend-export"));
      }
      $("#trend-summary").innerHTML =
        '<article class="trend-stat"><b>Temperature · ' + trendRangeLabel() + '</b><span>' +
        trendStats(data.points, "temperature", " °C", data.summary) + '</span></article>' +
        '<article class="trend-stat"><b>Humidity · ' + trendRangeLabel() + '</b><span>' +
        trendStats(data.points, "humidity", " %", data.summary) + '</span></article>';
      $("#tc").innerHTML = chart(data.points, "temperature", status.targetBands.temperatureC, "#176b4d", "Temperature", "°C", data.count, data.summary);
      $("#hc").innerHTML = chart(data.points, "humidity", status.targetBands.humidityPercent, "#2f5fbf", "Humidity", "%", data.count, data.summary);
    } catch (error) {
      $("#tc").textContent = error.message;
      $("#hc").textContent = error.message;
    }
  };

  window.addEventListener("DOMContentLoaded", () => {
    const demoEntry = document.querySelector("[data-action='start-instant']");
    if (demoEntry) {
      demoEntry.textContent = "Demo mode";
      demoEntry.classList.remove("demo-link");
    }
    fetch("/api/health").then((response) => response.json()).then((health) => {
      guidedDemoEnabled = health.guidedDemoEnabled === true;
      const notice = $("#gate-notice");
      if (notice && !guidedDemoEnabled) {
        notice.textContent = "Guided Demo is off. On the computer, open the Peo Yame tray menu and choose Demo mode.";
      }
    }).catch(() => {
      const notice = $("#gate-notice");
      if (notice) notice.textContent = "Demo availability could not be checked. On the computer, open the Peo Yame tray menu and choose Demo mode.";
    });
    setInterval(updateReadingAge, 1000);
    setInterval(ensureHeader, 1000);
  }, { once: true });
})();
