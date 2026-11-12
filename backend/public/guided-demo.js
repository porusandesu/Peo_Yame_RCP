(() => {
  const style = document.createElement("style");
  style.textContent = `
    dialog.py-dialog{border:0;border-radius:20px;max-width:min(440px,calc(100vw - 32px));padding:24px;color:#14231b}
    dialog.py-dialog::backdrop{background:#0b1410a6}
    dialog.py-dialog h2{margin:0 0 12px}
    dialog.py-dialog .py-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:18px}
    dialog.py-dialog input{width:100%;min-height:48px;border:1px solid #768a80;border-radius:10px;padding:10px;font:inherit}
    dialog.py-dialog [role=status]{min-height:24px;color:#8a3027}
    .py-qr-countdown{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
    .py-demo-step{display:flex;align-items:flex-start;gap:10px;padding:8px 0}
    .py-demo-step input{width:20px;height:20px;margin-top:2px}
    .py-settings-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}
    .py-settings-card{margin:0;box-shadow:0 8px 26px #1128210b}
    .py-settings-card.py-settings-wide{grid-column:1/-1}
    .py-settings-heading{display:flex;align-items:flex-start;gap:12px;margin-bottom:16px}
    .py-settings-heading h2{margin:0 0 5px}
    .py-settings-heading p{margin:0}
    .py-settings-icon{width:42px;height:42px;flex:0 0 42px;display:grid;place-items:center;border-radius:14px;background:#e1f0e6;color:#0f4a35;font-weight:800}
    .py-settings-actions{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
    .py-settings-card .py-settings-actions button{min-width:160px}
    @media(max-width:700px){.py-settings-grid{grid-template-columns:1fr}}
  `;
  document.head.append(style);

  let webQrGeneration = 0;
  let phoneQrGeneration = 0;
  let checklistSteps = [];
  let originalRender;
  let originalLoadSites;
  let originalLoadAlerts;

  function makeButton(text, handler, className = "") {
    const button = document.createElement("button");
    button.textContent = text;
    if (className) button.className = className;
    button.addEventListener("click", handler);
    return button;
  }

  function makeDialog(title, body) {
    const dialog = document.createElement("dialog");
    dialog.className = "py-dialog";
    const heading = document.createElement("h2");
    heading.textContent = title;
    dialog.append(heading, body);
    document.body.append(dialog);
    dialog.addEventListener("close", () => dialog.remove(), { once: true });
    dialog.showModal();
    return dialog;
  }

  async function requestJson(path, body) {
    const headers = { "content-type": "application/json" };
    const csrf = document.cookie.split(";").map((item) => item.trim())
      .find((item) => item.startsWith("py_csrf="))?.slice(8);
    if (csrf) headers["x-csrf-token"] = csrf;
    if (token) headers.authorization = "Bearer " + token;
    const response = await fetch("/api" + path, {
      method: "POST",
      headers,
      body: JSON.stringify(body),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw Error(data.error || "Request failed.");
    return data;
  }

  async function cancelWebCode(codeId, verifier) {
    try {
      await requestJson("/qr/web/cancel", { codeId, verifier });
    } catch (error) {
      console.warn("Could not cancel the old sign-in code:", error.message);
    }
  }

  async function createWebQr(generation) {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    const verifier = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
    const verifierHash = await sha256Hex(verifier);
    const data = await api("/qr/web/create", {
      method: "POST",
      body: JSON.stringify({ verifierHash }),
    });
    if (generation !== webQrGeneration) return;

    const box = document.createElement("div");
    box.className = "card";
    const image = document.createElement("img");
    image.src = data.qrDataUrl;
    image.alt = "Sign-in QR code";
    image.width = 220;
    const countdown = document.createElement("p");
    countdown.className = "py-qr-countdown";
    countdown.setAttribute("aria-live", "off");
    const announcement = document.createElement("span");
    announcement.className = "muted";
    announcement.setAttribute("role", "status");
    const manual = document.createElement("p");
    manual.className = "muted";
    manual.textContent = "Can't scan? Enter code: " +
      (data.shortCode ? data.shortCode.slice(0, 4) + "-" + data.shortCode.slice(4) : "unavailable");
    const refresh = makeButton("Get a new code", async () => {
      ++webQrGeneration;
      clearInterval(timer);
      await cancelWebCode(data.codeId, verifier);
      window.startWebQr();
    });
    const match = document.createElement("p");
    match.className = "muted";
    match.textContent = "Match code " + data.matchCode;
    box.append(image, match, countdown, refresh, manual, announcement);
    $("#webqr").replaceChildren(box);

    const expiresAt = Date.parse(data.expiresAt);
    let announced30 = false;
    let announced10 = false;
    const timer = setInterval(async () => {
      if (generation !== webQrGeneration) {
        clearInterval(timer);
        return;
      }
      const remaining = Math.max(0, Math.ceil((expiresAt - Date.now()) / 1000));
      countdown.textContent = remaining > 0
        ? `Expires in ${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")} · works once`
        : "This code expired. Get a new one.";
      if (remaining <= 30 && !announced30) {
        announced30 = true;
        announcement.textContent = "Sign-in code expires in 30 seconds.";
      }
      if (remaining <= 10 && !announced10) {
        announced10 = true;
        announcement.textContent = "Sign-in code expires in 10 seconds.";
      }
      try {
        const state = await api("/qr/web/status?codeId=" + encodeURIComponent(data.codeId) +
          "&verifier=" + encodeURIComponent(verifier));
        if (state.state === "approved") {
          clearInterval(timer);
          const session = await api("/qr/web/redeem", {
            method: "POST",
            body: JSON.stringify({ codeId: data.codeId, verifier }),
          });
          token = session.token;
          mode = session.isDemo ? "guided" : "farmer";
          await enter();
          banner("Signed in as " + session.user.name);
          return;
        }
        if (state.state === "denied") {
          clearInterval(timer);
          countdown.textContent = "This request was denied.";
          return;
        }
        if (state.state === "expired") {
          clearInterval(timer);
          ++webQrGeneration;
          await cancelWebCode(data.codeId, verifier);
          window.startWebQr();
          return;
        }
        if (state.state === "scanned" && remaining <= 10) return;
        if (remaining <= 10) {
          clearInterval(timer);
          ++webQrGeneration;
          await cancelWebCode(data.codeId, verifier);
          window.startWebQr();
        }
      } catch (error) {
        if (remaining <= 0) {
          clearInterval(timer);
          countdown.textContent = "This code expired. Get a new one.";
        } else {
          announcement.textContent = error.message || "Connection interrupted. Retrying this code.";
        }
      }
    }, 1000);
  }

  window.startWebQr = async function startWebQr() {
    const generation = ++webQrGeneration;
    $("#webqr").textContent = "Creating a sign-in code…";
    try {
      await createWebQr(generation);
    } catch (error) {
      if (generation === webQrGeneration) $("#webqr").textContent = error.message;
    }
  };

  function approvalDialog(details, codeId, state) {
    const body = document.createElement("div");
    const detail = document.createElement("p");
    detail.textContent = `Device: ${details.deviceName || "Phone"} · ${details.appVersion || "Peo Yame"}\nRequested: ${new Date(details.createdAt).toLocaleTimeString()}`;
    const networkAddress = document.createElement("p");
    networkAddress.className = "muted";
    networkAddress.textContent = "Network address hidden";
    const revealAddress = makeButton("Show network address", () => {
      const visible = revealAddress.textContent === "Show network address";
      networkAddress.textContent = visible
        ? `Network address: ${details.address || "Unavailable"}`
        : "Network address hidden";
      revealAddress.textContent = visible ? "Hide network address" : "Show network address";
    });
    const notice = document.createElement("p");
    notice.className = "notice";
    notice.textContent = "Only approve if you started this on your phone just now.";
    const field = document.createElement("input");
    field.inputMode = "numeric";
    field.maxLength = 2;
    field.autocomplete = "one-time-code";
    field.setAttribute("aria-label", "Enter the 2-digit number shown on your phone");
    const status = document.createElement("p");
    status.setAttribute("role", "status");
    const actions = document.createElement("div");
    actions.className = "py-actions";
    const deny = makeButton("Deny", async () => {
      deny.disabled = true;
      approve.disabled = true;
      try {
        await api("/qr/phone/deny", { method: "POST", body: JSON.stringify({ codeId }) });
        state.handled = true;
        state.status.textContent = "This request was denied.";
        state.close();
      } catch (error) {
        status.textContent = error.message;
        deny.disabled = false;
        approve.disabled = false;
      }
    });
    const approve = makeButton("Approve", async () => {
      if (!/^\d{2}$/.test(field.value.trim())) {
        status.textContent = "Enter the 2-digit number shown on your phone.";
        field.focus();
        return;
      }
      approve.disabled = true;
      deny.disabled = true;
      try {
        await api("/qr/phone/approve", {
          method: "POST",
          body: JSON.stringify({ codeId, matchCode: field.value.trim() }),
        });
        state.handled = true;
        state.status.textContent = "Phone approved. Waiting for connection.";
        state.close();
      } catch (error) {
        status.textContent = error.message;
        if (/Too many tries/.test(error.message)) {
          state.handled = true;
          state.close();
        } else {
          field.value = "";
          field.focus();
          approve.disabled = false;
          deny.disabled = false;
        }
      }
    }, "primary");
    actions.append(deny, approve);
    body.append(detail, networkAddress, revealAddress, notice, field, status, actions);
    const dialog = makeDialog("Approve phone sign-in?", body);
    field.focus();
    state.status = status;
    const closeState = state.close.bind(state);
    state.close = () => {
      closeState();
      dialog.close();
    };
    dialog.addEventListener("cancel", async (event) => {
      event.preventDefault();
      await deny.click();
    });
    return dialog;
  }

  async function createPhoneQr(reuseCodeId = null) {
    if (!reuseCodeId) {
      const password = prompt("Re-enter your password to create a phone sign-in code.");
      if (password === null || !password) throw Error("Password re-check is required.");
      const totpCode = prompt("If you use an authenticator app, enter its 6-digit code; otherwise leave this blank.") || "";
      return requestJson("/qr/phone/create", { password, totpCode });
    }
    return requestJson("/qr/phone/renew", { codeId: reuseCodeId });
  }

  window.connectPhone = async function connectPhone(existingData = null) {
    const generation = ++phoneQrGeneration;
    const host = $("#phone-qr");
    let data = existingData;
    if (!data) {
      host.textContent = "Creating a phone connection code…";
      try {
        data = await createPhoneQr();
      } catch (error) {
        host.textContent = error.message;
        return;
      }
    }
    let handled = false;
    let dialogOpen = false;
    let approvalDialogRef = null;
    const box = document.createElement("div");
    box.className = "card";
    const image = document.createElement("img");
    image.src = data.qrDataUrl;
    image.alt = "Connect phone QR code";
    image.width = 220;
    const address = document.createElement("p");
    address.className = "muted";
    address.textContent = "Phone and computer must be on the same Wi-Fi. HTTP is for a controlled private network.";
    const countdown = document.createElement("p");
    countdown.className = "py-qr-countdown";
    const manual = document.createElement("p");
    manual.className = "muted";
    manual.textContent = "Can't scan? Enter code: " +
      (data.shortCode ? data.shortCode.slice(0, 4) + "-" + data.shortCode.slice(4) : "unavailable");
    const stateText = document.createElement("p");
    stateText.className = "muted";
    stateText.textContent = "Waiting for a phone to scan.";
    const refresh = makeButton("Get a new code", async () => renew());
    box.append(image, address, countdown, refresh, manual, stateText);
    host.replaceChildren(box);

    async function renew() {
      if (dialogOpen) return;
      clearInterval(timer);
      try {
        const next = await createPhoneQr(data.codeId);
        window.connectPhone(next);
      } catch (error) {
        stateText.textContent = error.message;
      }
    }

    const expiresAt = Date.parse(data.expiresAt);
    const timer = setInterval(async () => {
      if (generation !== phoneQrGeneration) {
        clearInterval(timer);
        return;
      }
      const remaining = Math.max(0, Math.ceil((expiresAt - Date.now()) / 1000));
      countdown.textContent = remaining > 0
        ? `Expires in ${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")} · works once`
        : "This code expired. Get a new one.";
      try {
        const requestState = await api("/qr/phone/owner-status?codeId=" + encodeURIComponent(data.codeId));
        if (requestState.state === "scanned" && !handled) {
          handled = true;
          dialogOpen = true;
          refresh.disabled = true;
          approvalDialogRef = approvalDialog(requestState, data.codeId, {
            get status() { return stateText; },
            set status(value) { stateText.textContent = value; },
            close() { dialogOpen = false; refresh.disabled = false; },
            get handled() { return handled; },
            set handled(value) { handled = value; },
          });
          stateText.textContent = "Phone is waiting for approval.";
        } else if (requestState.state === "completed") {
          clearInterval(timer);
          stateText.textContent = "Phone connected.";
        } else if (requestState.state === "denied") {
          clearInterval(timer);
          stateText.textContent = "This request was denied.";
          if (dialogOpen) {
            dialogOpen = false;
            refresh.disabled = false;
            approvalDialogRef?.close();
          }
        } else if (requestState.state === "cancelled") {
          clearInterval(timer);
          stateText.textContent = "The phone canceled this request.";
          if (dialogOpen) {
            dialogOpen = false;
            refresh.disabled = false;
            approvalDialogRef?.close();
          }
        } else if (requestState.state === "expired") {
          clearInterval(timer);
          if (dialogOpen) {
            stateText.textContent = "This code expired. Start again.";
            dialogOpen = false;
            refresh.disabled = false;
            approvalDialogRef?.close();
          }
          else await renew();
        } else if (remaining <= 10 && !dialogOpen) {
          await renew();
        }
      } catch (error) {
        if (remaining <= 0) {
          clearInterval(timer);
          stateText.textContent = "This code expired. Get a new one.";
        } else {
          stateText.textContent = error.message || "Could not check the phone request.";
        }
      }
    }, 1000);
  };

  function renderChecklist(host) {
    if (!host) return;
    host.querySelector(".py-run-sheet")?.remove();
    const section = document.createElement("section");
    section.className = "py-run-sheet";
    const pending = checklistSteps.find((step) => !step.completed);
    const next = document.createElement("p");
    next.className = "muted";
    next.textContent = pending ? "Next step: " + pending.title : "Run sheet complete.";
    section.append(next);
    for (const step of checklistSteps) {
      const row = document.createElement("label");
      row.className = "py-demo-step";
      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = step.completed;
      checkbox.addEventListener("change", async () => {
        checkbox.disabled = true;
        try {
          await api("/demo/checklist/" + step.step, {
            method: "PATCH",
            body: JSON.stringify({ completed: checkbox.checked }),
          });
          await window.refreshDemoSettings();
        } catch (error) {
          checkbox.checked = !checkbox.checked;
          checkbox.disabled = false;
          banner(error.message, true);
        }
      });
      const title = document.createElement("span");
      title.textContent = step.title;
      row.append(checkbox, title);
      section.append(row);
    }
    host.append(section);
  }

  window.refreshDemoSettings = async function refreshDemoSettings() {
    if (mode !== "guided") return;
    const [simulation, checklist] = await Promise.all([
      api("/demo/simulation"),
      api("/demo/checklist"),
    ]);
    demoSimulationActive = simulation.active === true;
    checklistSteps = checklist.steps || [];
    const toggle = $("#demo-live-toggle");
    const status = $("#demo-simulation-status");
    if (toggle) toggle.textContent = demoSimulationActive ? "Stop live simulation" : "Start live simulation";
    if (status) status.textContent = demoSimulationActive
      ? "Simulated readings are syncing to signed-in demo devices."
      : "";
    renderChecklist($("#demo-card"));
  };

  window.startGuided = async function startGuided() {
    if (!confirm("Start a temporary Guided Demo account with simulated data? Its generated password will be shown once.")) return;
    try {
      const data = await api("/demo/start", { method: "POST", body: "{}" });
      token = data.token;
      mode = "guided";
      page = "Overview";
      startEvents();
      render();
      await refresh();
      const content = document.createElement("div");
      content.innerHTML = "<p>This password is displayed only once. Keep it available for authenticator setup and QR phone pairing.</p>";
      const secret = document.createElement("p");
      secret.className = "py-demo-password";
      secret.textContent = data.demoPassword;
      secret.style.cssText = "font-family:monospace;font-size:18px;word-break:break-all";
      const actions = document.createElement("div");
      actions.className = "py-actions";
      actions.append(
        makeButton("Copy password", async () => {
          if (!navigator.clipboard?.writeText) {
            alert("Clipboard access is unavailable here. Select and copy the displayed password.");
            return;
          }
          try {
            await navigator.clipboard.writeText(data.demoPassword);
          } catch {
            alert("Clipboard access was denied. Select and copy the displayed password.");
          }
        }),
        makeButton("Continue", () => dialog.close(), "primary"),
      );
      content.append(secret, actions);
      const dialog = makeDialog("Save your Guided Demo password", content);
      banner("Demo session. Data is simulated and will be deleted.");
    } catch (error) {
      alert(error.message);
    }
  };

  function showEstimate(container, estimate) {
    if (!estimate || !Array.isArray(estimate.rangeWeeks)) return;
    const block = document.createElement("div");
    block.className = "muted py-estimate";
    const title = document.createElement("p");
    title.textContent = `Rough storage estimate · About ${estimate.rangeWeeks[0]}–${estimate.rangeWeeks[1]} weeks · Rough risk: ${estimate.risk}`;
    const disclaimer = document.createElement("p");
    disclaimer.textContent = estimate.disclaimer ||
      "A rough guess from temperature and humidity only. It does not inspect your crop. Check your crops by hand every few days.";
    block.append(title, disclaimer);
    container.append(block);
  }

  originalLoadSites = window.loadSites;
  window.loadSites = async function loadSitesWithEstimates() {
    await originalLoadSites();
    const cards = $("#sites")?.querySelectorAll(".item") || [];
    cards.forEach((card, index) => showEstimate(card, sites[index]?.estimate));
    if (mode === "guided" && sites.length === 0) renderChecklist($("#sites"));
  };

  originalLoadAlerts = window.loadAlerts;
  window.loadAlerts = async function loadAlertsWithEstimates() {
    await originalLoadAlerts();
    const cards = $("#alerts")?.querySelectorAll(".item") || [];
    cards.forEach((card, index) => showEstimate(card, alerts[index]?.estimate));
  };

  originalRender = window.render;
  window.render = function renderWithBackendQr(...args) {
    const result = originalRender(...args);
    const refreshButton = document.querySelector("#refresh-data-button");
    if (refreshButton) {
      refreshButton.textContent = mode === "guided" || mode === "instant"
        ? "Refresh demo data"
        : "Refresh data now";
    }
    if (page === "Settings") {
      ensureBackendQrControls();
      if (mode === "guided") window.refreshDemoSettings().catch((error) => banner(error.message, true));
    }
    return result;
  };

  function ensureBackendQrControls() {
    const heading = [...document.querySelectorAll("h2")].find((item) => item.textContent === "Backend connection");
    const host = heading?.closest(".py-settings-card") || heading?.parentElement;
    if (!heading || !host || host.querySelector("#backend-qr-controls")) return;
    const controls = document.createElement("div");
    controls.id = "backend-qr-controls";
    const button = makeButton("Show backend connection QR", async () => {
      button.disabled = true;
      try {
        const result = await api("/backend/qr");
        const panel = document.createElement("div");
        panel.className = "card";
        const image = document.createElement("img");
        image.src = result.qrDataUrl;
        image.alt = "Backend connection QR code";
        image.width = 240;
        const address = document.createElement("p");
        address.textContent = "Backend address hidden";
        const revealAddress = makeButton("Show backend address", () => {
          const visible = revealAddress.textContent === "Show backend address";
          address.textContent = visible ? result.baseUrl : "Backend address hidden";
          revealAddress.textContent = visible ? "Hide backend address" : "Show backend address";
        });
        const note = document.createElement("p");
        note.className = "muted";
        note.textContent = "Scan from Settings → Backend connection. Phone and computer must be on the same Wi-Fi. Plain HTTP is for a controlled private network only.";
        panel.append(image, address, revealAddress, note);
        controls.replaceChildren(panel, makeButton("Hide QR code", () => controls.replaceChildren(button)));
      } catch (error) {
        banner(error.message, true);
      } finally {
        button.disabled = false;
      }
    });
    controls.append(button);
    host.append(controls);
  }
})();
