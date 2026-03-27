{
  lib,
  writeTextFile,
  ulypkgsPackages,
}:

# must use writeTextFile instead of writeText to avoid evaluating the text just to evaluate this package
writeTextFile {
  name = "listing.html";
  text = ''
    <!DOCTYPE html>
    <html lang="en-US">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>ulypkgs</title>
      </head>
      <body>
        <h1>ulypkgs</h1>
        <p>Here is a list of all packages added by ulypkgs.</p>
        <ul>
          ${lib.concatMapAttrsStringSep "\n" (
            attr: package:
            if lib.isDerivation package then
              ''
                <li><details>
                  <summary><code>${attr}</code> (${package.name})</summary>
                  ${lib.optionalString (package ? meta.description) "<p>${package.meta.description}</p>"}
                  ${lib.optionalString
                    (package ? meta.homepage || package ? meta.changelog || package ? meta.downloadPage)
                    ''
                      <p>
                        ${lib.optionalString (
                          package ? meta.homepage
                        ) "<a href=\"${package.meta.homepage}\" target=\"_blank\">Homepage</a>"}
                        ${lib.optionalString (
                          package ? meta.changelog
                        ) "<a href=\"${package.meta.changelog}\" target=\"_blank\">Changelog</a>"}
                        ${lib.optionalString (
                          package ? meta.downloadPage
                        ) "<a href=\"${package.meta.downloadPage}\" target=\"_blank\">Download</a>"}
                      </p>
                    ''
                  }
                  ${lib.optionalString (package ? meta.license.fullName)
                    "<p>License: ${
                      if package ? meta.license.url then
                        "<a href=\"${package.meta.license.url}\" target=\"_blank\">${package.meta.license.fullName}</a>"
                      else
                        package.meta.license.fullName
                    }</p>"
                  }
                  <p>Outputs: ${lib.concatMapStringsSep ", " (o: "<code>\"${o}\"</code>") package.outputs}</p>
                  ${lib.optionalString (
                    package ? meta.position
                  ) "<p>Defined at ${lib.removePrefix "${toString ../.}/" package.meta.position}</p>"}
                </details></li>
              ''
            else
              ''
                <li><code>${attr}</code> (not a derivation)</li>
              ''
          ) ulypkgsPackages}
        </ul>
      </body>
    </html>
  '';

  meta.description = "HTML file listing all packages in this repository with their descriptions and links";
}
