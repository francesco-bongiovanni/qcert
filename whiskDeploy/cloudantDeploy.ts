import { Config, Design, Designs } from "./types";
import openwhisk = require("openwhisk");
import fs = require("fs");
import path = require("path");

try {
    const yaml = require('js-yaml')
    const cloudant = require('cloudant')
    const owDeploy = require('openwhisk-deploy')

    const config_file = path.resolve(__dirname, '..', '..', 'whiskDeploy', 'config.yml')

    let config: Config
    try {
	config = yaml.safeLoad(fs.readFileSync(config_file, 'utf8'));
    } catch (error) {
	console.error("Could not load the configuration file");
    }

    // Initialize the client
    const client = cloudant({ account: config.cloudant.username, password: config.cloudant.password })

    const design_file = path.resolve(__dirname, config.cloudant.designs)
    let designs: Designs
    try {
	designs = yaml.safeLoad(fs.readFileSync(design_file, 'utf8'));
    } catch (error) {
	console.error("Could not load the design file");
    }

    const create = (dbName: string) => {
    }

    let rootDbName: string
    try {
	rootDbName = designs.designs[0].dbname
    } catch (error) {
	console.error("Should have at least one design document")
    }

    const loadDesign = (dbName: string, view: any) => {
	var db = client.db.use(dbName);
	// First make sure the db is created
	client.db.create(dbName, function (err, body) {
	    console.log('Created database: %s', dbName)
	    // Then load the design document
	    db.insert({"views":view},
		      '_design/section', function (error, response) {
			  console.log("Loaded design document in: %s", dbName);        
		      });
	});
    }

    for (var i=0; i < designs.designs.length; i++) {
	const design=designs.designs[i];
	loadDesign(design.dbname,design.design.views);
    }

    // Create final openWhisk action

    const makeEffectiveParams = (effParams:string[]) : string => {
	var result = [ ];
	for (var i=0; i < effParams.length; i++) {
	    const param = effParams[i];
	    result.push("getView(\""+param+"\")");
	}
	return result.join(',');
    }

    let result_source : string = ""
    try {
	result_source += designs.post;
	result_source += "\n"
	result_source += "\n"
	result_source += "const openwhisk = require(\"openwhisk\");\n"

	result_source += "const getView = (dbName) => {\n"
	result_source += "\n"
	result_source += "const ow = openwhisk()\n"
	result_source += "try {" + "\n";
        result_source += "const entry = ow.actions.invoke({" + "\n";
        result_source += "actionName: `Bluemix_CloudantBYOB_CloudantBYOB/list-documents`," + "\n";
        result_source += "blocking: true," + "\n";
        result_source += "params: { dbname: dbName, params: { include_docs: true } }" + "\n";
	result_source += "})" + "\n";
        result_source += "var res = [];" + "\n";
        result_source += "for (var i = 0; i < docs.length; i++) {" + "\n";
        result_source += "    res.push(docs[i].doc);" + "\n";
        result_source += "}" + "\n";
        result_source += "return res;" + "\n";
	result_source += "} catch (err) {" + "\n";
        result_source += "console.error(err)" + "\n";
        result_source += "return { \"error\" : err };" + "\n";
	result_source += "}" + "\n";
	result_source += "}\n";
	result_source += "function main() { return db_post("+makeEffectiveParams(designs.post_input)+") }"
    } catch (error) {
	console.error("Couldn't create action source string from design document");
    }
    
    // Deploy

    /* Create YAML manifest (on the fly!) */
    const deploy : any = {
	"packages": [{
	    "name": "qcert",
	    "actions": [{
		"name": rootDbName,
		"source": result_source
	    }]
	}]
    }
    
    for (var i = 0; i < deploy.packages.length; i++) {
        const pkg = deploy.packages[i];
        pkg.params = {
            config: config
        }
    }

    console.log("### Deploy on OpenWhisk ###")
    const d = new owDeploy({
        apihost: config.whisk.apihost,
        api_key: config.whisk.api_key,
        namespace: config.whisk.namespace
    })
    d.deploy(deploy)
    
} catch (error) {
    console.error("Error during deployment");
}
