Class %IPM.Repo.Oras.ArtifactMetadata Extends (%RegisteredObject, %JSON.Adaptor)
{

/// See https://github.com/opencontainers/image-spec/blob/main/annotations.md
Property "org-opencontainers-image-title" As %String(%JSONFIELDNAME = "org.opencontainers.image.title");

Property "org-opencontainers-image-description" As %String(%JSONFIELDNAME = "org.opencontainers.image.description");

Property "org-opencontainers-image-version" As %String(%JSONFIELDNAME = "org.opencontainers.image.version");

Property "org-opencontainers-image-source" As %String(%JSONFIELDNAME = "org.opencontainers.image.source");

Property "org-opencontainers-image-created" As %String(%JSONFIELDNAME = "org.opencontainers.image.created");

Property "com-intersystems-ipm-allVersions" As %String(%JSONFIELDNAME = "com.intersystems.ipm.allVersions");

Property "com-intersystems-ipm-origin" As %String(%JSONFIELDNAME = "com.intersystems.ipm.origin");

Property "com-intersystems-ipm-deployed" As %String(%JSONFIELDNAME = "com.intersystems.ipm.deployed");

Property "com-intersystems-ipm-module-v1+xml" As %String(%JSONFIELDNAME = "com.intersystems.ipm.module.v1+xml");

}
