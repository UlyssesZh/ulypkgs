{
  lib,
  fetchFromGitHub,
  fetchPypi,
  buildPythonPackage,
}:

buildPythonPackage rec {
  pname = "certifi";
  version = "2019.11.28";

  src = fetchPypi {
    inherit pname version;
    sha256 = "25b64c7da4cd7479594d035c08c2d809eb4aab3a26e5a990ea98cc450c320f1f";
  };

  certifiSrc = fetchFromGitHub {
    owner = "certifi";
    repo = "python-certifi";
    rev = "2021.10.08";
    sha256 = "sha256-SFb/spVHK15b53ZG1P147DcTjs1dqR0+MBXzpE+CWpo=";
  };

  postPatch = ''
    cp ${certifiSrc}/certifi/cacert.pem certifi/cacert.pem
  '';

  pythonImportsCheck = [ "certifi" ];

  # no tests implemented
  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/certifi/python-certifi";
    description = "Python package for providing Mozilla's CA Bundle";
    license = licenses.isc;
    maintainers = with maintainers; [ ]; # NixOps team
  };
}
