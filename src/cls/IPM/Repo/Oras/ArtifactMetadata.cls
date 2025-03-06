Class %IPM.Repo.Oras.ArtifactMetadata Extends (%RegisteredObject, %JSON.Adaptor)
{

/// See https://github.com/opencontainers/image-spec/blob/main/annotations.md
Property ImageTitle As %String(%JSONFIELDNAME = "org.opencontainers.image.title");

Property ImageDescription As %String(%JSONFIELDNAME = "org.opencontainers.image.description");

Property ImageVersion As %String(%JSONFIELDNAME = "org.opencontainers.image.version");

Property ImageSource As %String(%JSONFIELDNAME = "org.opencontainers.image.source");

Property ImageCreated As %String(%JSONFIELDNAME = "org.opencontainers.image.created");

Property IPMAllVersions As %String(%JSONFIELDNAME = "com.intersystems.ipm.allVersions");

Property IPMOrigin As %String(%JSONFIELDNAME = "com.intersystems.ipm.origin");

Property IPMDeployed As %String(%JSONFIELDNAME = "com.intersystems.ipm.deployed");

Property IPMModuleV1XML As %String(%JSONFIELDNAME = "com.intersystems.ipm.module.v1+xml");

}
