export interface Config {
    cloudant: {
        designs: string;   /** name of Cloudant designs file produced by Q*cert */
        username: string;  /** name of Cloudant username */
        password: string;  /** name of Cloudant password */
    }
    whisk: {
        namespace: string;
        api_key: string;
        apihost: string;
    }
}

export interface Design {
    dbname: string;     /** Cloudant database name */
    design: { views: any; };         /** Cloudant view */
}

export interface Designs {
    designs: Design[];      /** Design documents */
    post: string;           /** Post-processing expression */
    post_input: string[];   /** Effective parameters for the post-processing expression */
}

