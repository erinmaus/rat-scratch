const AdmZip = require("adm-zip");
const http = require("http");
const crypto = require("crypto");
const path = require("path");
const fs = require("fs");

const BASE_PATH = path.join(process.cwd(), "./rat-scratch-test");

const iterate = (folder, filter) => {
	const entries = fs
		.readdirSync(folder)
		.map((entry) => path.join(folder, entry))
		.filter((filename) => !filter || filter(filename));

	const folders = entries.filter((filename) =>
		fs.statSync(filename).isDirectory(),
	);
	const files = entries.filter((filename) => fs.statSync(filename).isFile());

	const result = folders.reduce(
		(currentFiles, folder) => [...currentFiles, ...iterate(folder)],
		files,
	);
	result.sort();

	return result;
};

const makeHash = (buffer) => {
	const hash = crypto.createHash("sha256");
	hash.update(buffer);
	return hash.digest("hex");
};

const makeZip = (folder) => {
	const zipFolder = folder.replace(/\.([^\.]*)$/, ".zip");
	if (fs.existsSync(zipFolder) && fs.statSync(zipFolder).isFile()) {
		const result = fs.readFileSync(zipFolder);
		console.log("--- cache", {
			zipFolder,
			hash: makeHash(result),
		});
		return result;
	}

	const zip = new AdmZip();

	const folderPath = folder.replace(/\.([^\.]*)$/, "");
	const basename = path.basename(folderPath);
	const excluded = [`${basename}/lib`, `${basename}/build`];

	const files = iterate(
		folderPath,
		(filename) => !excluded.some((path) => filename.startsWith(path)),
	);

	files.forEach((filename) => {
		const zipFilename = path.relative(path.dirname(folderPath), filename);
		zip.addFile(zipFilename, fs.readFileSync(filename));
	});

	const zipBuffer = zip.toBuffer();
	console.log("--- rebuild", {
		zipFolder,
		hash: makeHash(zipBuffer),
	});

	fs.writeFileSync(zipFolder, zipBuffer);
	return zipBuffer;
};

const serveHash = (folder) => {
	const code = makeHash(makeZip(folder));
	return { mimeType: "text/plain", content: code };
};

const serveZip = (folder) => {
	return { mimeType: "application/zip", content: makeZip(folder) };
};

const server = http.createServer((request, response) => {
	const url = decodeURI(request.url);
	if (url === "/quit") {
		response.writeHead(200);
		response.end();
		server.close();
		return;
	}

	const folder = path.join(BASE_PATH, url);

	try {
		let result;
		if (path.extname(folder) === ".zip") {
			result = serveZip(folder);
		} else if (path.extname(folder) === ".sha256") {
			result = serveHash(folder);
		} else {
			response.writeHead(404);
			return;
		}

		response.writeHead(200, {
			"content-type": result.mimeType,
		});

		response.write(result.content);
	} catch (error) {
		console.log(error);

		response.writeHead(500);
		response.write(error.toString());
	}

	response.end();
});

server.listen(3000, () => {
	console.log("Running at http://localhost:3000");
});
