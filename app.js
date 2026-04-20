const fileInput = document.getElementById("file-input");
const searchInput = document.getElementById("search-input");
const resultsBody = document.getElementById("results-body");
const warningPanel = document.getElementById("warning-panel");

let employees = [];

const normalizeHeader = (value) =>
  String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

const headerMatches = (header, keywords) => {
  const normalized = normalizeHeader(header);
  return keywords.some((keyword) => normalized.includes(keyword));
};

const parseNumber = (value) => {
  if (value === null || value === undefined || value === "") return 0;
  const parsed = Number(String(value).replace(/[^0-9.-]/g, ""));
  return Number.isFinite(parsed) ? parsed : 0;
};

const deriveNameParts = (row, nameHeaderMap) => {
  const firstName = row[nameHeaderMap.firstName] || "";
  const lastName = row[nameHeaderMap.lastName] || "";
  const fullName = row[nameHeaderMap.fullName] || "";

  if (firstName || lastName) {
    return {
      firstName: String(firstName).trim(),
      lastName: String(lastName).trim(),
    };
  }

  const full = String(fullName).trim();
  if (!full) {
    return { firstName: "", lastName: "" };
  }

  const parts = full.split(/\s+/);
  if (parts.length === 1) {
    return { firstName: parts[0], lastName: "" };
  }

  return {
    firstName: parts.slice(0, -1).join(" "),
    lastName: parts.slice(-1).join(" "),
  };
};

const getHeaderMap = (headers) => {
  const headerMap = {
    employeeNumber: "",
    sickTime: "",
    vacationTime: "",
    firstName: "",
    lastName: "",
    fullName: "",
  };

  headers.forEach((header) => {
    if (!header) return;
    if (
      !headerMap.employeeNumber &&
      headerMatches(header, ["employee number", "employee id", "emp id", "employee #", "emp #"])
    ) {
      headerMap.employeeNumber = header;
    }
    if (!headerMap.sickTime && headerMatches(header, ["sick time", "sick", "sick hours"])) {
      headerMap.sickTime = header;
    }
    if (
      !headerMap.vacationTime &&
      headerMatches(header, ["vacation time", "vacation", "vacation hours", "pto"])
    ) {
      headerMap.vacationTime = header;
    }
    if (!headerMap.firstName && headerMatches(header, ["first name", "fname", "first"])) {
      headerMap.firstName = header;
    }
    if (!headerMap.lastName && headerMatches(header, ["last name", "lname", "last"])) {
      headerMap.lastName = header;
    }
    if (!headerMap.fullName && headerMatches(header, ["employee name", "name", "full name"])) {
      headerMap.fullName = header;
    }
  });

  return headerMap;
};

const updateWarnings = () => {
  const noTime = employees.filter((employee) => employee.sickTime <= 0 || employee.vacationTime <= 0);
  if (employees.length === 0) {
    warningPanel.textContent = "Upload a file to see warnings.";
    warningPanel.classList.remove("ok");
    return;
  }

  if (noTime.length === 0) {
    warningPanel.textContent = "All employees have sick and vacation time available.";
    warningPanel.classList.add("ok");
    return;
  }

  warningPanel.classList.remove("ok");
  const names = noTime
    .map((employee) => `${employee.firstName} ${employee.lastName}`.trim() || employee.employeeNumber)
    .join(", ");
  warningPanel.textContent = `Warning: ${noTime.length} employee(s) have zero time available. ${names}`;
};

const renderRows = (rows) => {
  resultsBody.innerHTML = "";

  if (rows.length === 0) {
    const placeholderRow = document.createElement("tr");
    const placeholderCell = document.createElement("td");
    placeholderCell.colSpan = 5;
    placeholderCell.className = "placeholder";
    placeholderCell.textContent = employees.length
      ? "No employees match that search."
      : "Upload a spreadsheet to view results.";
    placeholderRow.appendChild(placeholderCell);
    resultsBody.appendChild(placeholderRow);
    return;
  }

  rows.forEach((employee) => {
    const row = document.createElement("tr");
    if (employee.sickTime <= 0 || employee.vacationTime <= 0) {
      row.classList.add("warning");
    }

    const cells = [
      employee.employeeNumber,
      employee.firstName,
      employee.lastName,
      employee.sickTime,
      employee.vacationTime,
    ];

    cells.forEach((value) => {
      const cell = document.createElement("td");
      cell.textContent = value;
      row.appendChild(cell);
    });

    resultsBody.appendChild(row);
  });
};

const handleSearch = () => {
  const query = searchInput.value.trim().toLowerCase();
  if (!query) {
    renderRows(employees);
    return;
  }

  const filtered = employees.filter((employee) => {
    const fullName = `${employee.firstName} ${employee.lastName}`.toLowerCase();
    return (
      employee.employeeNumber.toLowerCase().includes(query) ||
      employee.firstName.toLowerCase().includes(query) ||
      employee.lastName.toLowerCase().includes(query) ||
      fullName.includes(query)
    );
  });

  renderRows(filtered);
};

const loadSpreadsheet = async (file) => {
  const buffer = await file.arrayBuffer();
  const workbook = XLSX.read(buffer, { type: "array" });
  const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
  if (!firstSheet) {
    employees = [];
    renderRows([]);
    updateWarnings();
    return;
  }

  const rows = XLSX.utils.sheet_to_json(firstSheet, { defval: "" });
  if (!rows.length) {
    employees = [];
    renderRows([]);
    updateWarnings();
    return;
  }

  const headers = Object.keys(rows[0]);
  const headerMap = getHeaderMap(headers);

  employees = rows.map((row) => {
    const nameParts = deriveNameParts(row, headerMap);
    return {
      employeeNumber: String(row[headerMap.employeeNumber] || "").trim(),
      firstName: nameParts.firstName,
      lastName: nameParts.lastName,
      sickTime: parseNumber(row[headerMap.sickTime]),
      vacationTime: parseNumber(row[headerMap.vacationTime]),
    };
  });

  updateWarnings();
  renderRows(employees);
};

fileInput.addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    await loadSpreadsheet(file);
    searchInput.disabled = false;
    searchInput.value = "";
  } catch (error) {
    employees = [];
    searchInput.disabled = true;
    resultsBody.innerHTML = "";
    const row = document.createElement("tr");
    const cell = document.createElement("td");
    cell.colSpan = 5;
    cell.className = "placeholder";
    cell.textContent = "Unable to read that file. Please upload a valid spreadsheet.";
    row.appendChild(cell);
    resultsBody.appendChild(row);
    warningPanel.textContent = "Could not read the uploaded file.";
    warningPanel.classList.remove("ok");
    console.error(error);
  }
});

searchInput.addEventListener("input", handleSearch);
