OSG-CA-SCRIPTS
==============

Syntax
-----
       osg-ca-manage [global_options] command
        global_options =
            [--verbose]
            [--force]
            [--cert-dir <location>]
            [--help | --usage]
            [--version]
            [--auto-refresh]

        command = [manage_command | status_command]

        status_command = [
            showCAURL |
            listCA [--pattern <pattern>] |
            verify [--hash <CA hash>  | --pattern <pattern>] |
            diffCAPackage |
            show [--certfile <cert_file> | --hash <CA hash>] |
            showChain [--certfile <cert_file> | --hash <CA hash>]
        ]

        manage_command = [
            setupCA --location <root|PATH> [--url <osg|igtf|URL> --no-update --force] |
            refreshCA |
            fetchCRL |
            setCAURL [--url <osg|igtf|URL>] |
            add [--cadir <localdir> | --caname <CA>]
            remove [--cadir <localdir> | --caname <CA>]
        ]

### Explanation of global options

Zero or more of these options may be used during an execution of ca\_manage.

1. `--verbose` Provides you with more information depending on the command context.
2. `--force` Forces the command to run ignoring any checks/warnings. The actual effect is context dependent, and this behavior is noted in the command details below.>
3. `--cert-dir <location>` This location specifies the path CA directory. If this option is not specified then the command will look for `$X509_CERT_DIR` followed by `/etc/grid-security/certificates`. If none of these directories can be found, the command will exit with an error.
4.  `--auto-refresh ` This option will indicate if this permissible to fetch CAs and CRLs as deemed necessary by this tool. For example at the end of an addCA/removeCA it would be advisable to refresh the CA list and the corresponding CRLs. Default is **not** to refresh, unless the admin requests it by specifying this option.
5.  `--version` Prints the version of the `osg-ca-manage` tool.
6.  `--help | --usage` Print usage information. Show a brief explanatory text for using osg-ca-manage.

### Explanation of commands

Exactly one command is to be specified during an execution of osg-ca-manage

#### Status commands

1.   `showCAURL` This will print out the distribution location specified in the config file. This command will read osg-update-certs.conf and output cacerts_url.
2.   `listCA [--pattern <pattern>]` This command will use openssl x509 command on the files in the --dir to provide hash, the subject and whether a CA is IGTF or TeraGrid accredited and distribution package which was used to download CAs into the directory. --verbose option will provide additional information like issuer (of CA) and all associated dates (CA cert issuance date, and CRL issuance date, and expiry dates). The command will look for CA files in the -certDir. The `<pattern>` specified in the option will be matched, using perl regex, against the subject field of the certificate (but we might also expand it include issuer if needed) and all CAs are listed if no pattern is given.
3.   `verify [--hash <CA_hash> | --pattern <pattern>]` The verify command will check all CAs (or if specified only the `<CA_hash>`) in the `<certDir>` directory, to see if any CA/CRL have expired or are about to do so. If any expired CA/CRL are found, an error is issued along with the hash, date when CA cert/CRL expired. A warning is issued if either the CA cert or CRL is about the expire within the next 24 Hrs. The --verbose option provides the CA Name, date the CA certs and CRL files are created (by the CA), and when they will expire. In addition to hash value we will also consider providing an option of verify using `<pattern>`
4. `diffCAPackage` This command will compare the hash of certificates included in the certificate directory against the latest OSG distribution (based on your `cacerts_url`) and outputs the difference.
5. `show [--certfile <cert_file> | --hash <CA_hash>]` This command will essentially provide a condensed output of openssl x509 command. --verbose option will provide the full output. If --hash option is used we will look for the `<CA_hash>.o` file in the `<certDir>`. The --certfile option can also take in a user proxy.
6. `showChain [--certfile <cert_file> | --hash <CA_hash>]` This command will output the trust chain of the certificate. `<certDir>` will be used as the directory in which search for ancestor certs will be conducted. This command can also be used to trace the trust chain of a user proxy.

#### Manage commands ####

1.  `setupCA --location <root|PATH> [--url <osg|igtf|URL> --no-update --force]` This command is used for the inital setup of the CA package. The CA package can be setup to download CAs from any URL. Keywords are provided for various distributions. For the location to specify, keywords are provided to install into 'root' (/etc/grid-security). A --no-update option is available. Setting this flag instructs just setup the symlinks only and not to run configure osg-update-certs to be run automatically. This option is for installations that will not manage their own certificates, but will rely on updates through another method (such as RPM, or using osg-update-certs from a different OSG installation). A common use case for this is to have worker-node installations rely on theCA certificates being available on an NFS share, and the updating will happen on a single node.
2.   `refreshCA` This command run osg-update-certs to check for a new version of the CA distribution. If you already have the latest version, but wish to force an update anyways, use the --force option. 1.`fetchCRL` It retrieves CRLs for all CAs within the directory. This will involve invoking fetch-crl, with appropriate arguments. NOTE: If the OSG's 's fetch-crl service has not been enabled, then this command will not execute. This is a safety mechanism to prevent crls from being downloaded using this tool if they are not scheduled to be updated.
3.   `setCAURL [--url <osg|igtf|URL>]` This command sets the location from where the CA files. This command will modify vdt-update-certs.conf and set the cacerts\_url as `<URL_location>`. Only if --auto-refresh is specified both CA and CRLs are refreshed once the URL change has been made. The distribution `<URL_location>` will be required to conform to the CA distribution format (e.g. similar to <https://repo.opensciencegrid.org/pacman/cadist/ca-certs-version-igtf-new>). If the `<URL_location>` cannot be reached or if it is valid syntactically (i.e. does not conform to the format requirements) a warning will be issues and no changes will be made. The --force option can be used to force a change ignoring the warning. If URL location is left unspecified the `<URL_location>` will be set to OSG default. We define keywords for OSG, IGTF as shortcuts for OSG wide well-known CA URL\_locations.
4.   `add [--cadir <localdir> | --caname <CA>]` The --hash argument is required. If --dir is not specified we will assume that the user wants to include a CA he has previously excluded and will remove the corresponding exclude lines from the config. If `<CA_hash>` is not known to us or it is already included we will provide appropriate error/warning information. In the common case this command will add include lines for `<local_dir>`/`<CA_hash>`.0, into the vdt-update-certs.conf file. Lastly the command will invoke functions refresh the CAs and fetch CRLs. This command will also do some preliminary error checks, e.g.make sure that “.0”, “.crl\_url”, “.signing\_policy” files exist and that --dir is different than --certDir.
5.   `remove [--cadir <localdir> | --caname <CA>]` This command will be complementary to add and would either add an exclude or remove an include depending on the scenario. This command will also refresh CA and CRLs. vdt-update-certs do the job of removing cert files, we will still do the preliminary error checks to make sure that the certs that are being removed are included in the first place. For both addCA and removeCA, new CAs will be included/removed and CRLs will be refreshed only if --auto-refresh is set.

