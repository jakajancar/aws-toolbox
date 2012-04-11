#!/bin/bash
#
# AWS Toolbox installer
#
# Copyright (c) 2011 Jaka Jancar <jaka@kubje.org>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -eu -o pipefail

fail() {
    echo "$(basename $0): error: $1" >&2
    exit 1
}

INSTALL_DIR=${INSTALL_DIR:-$HOME/opt/aws-toolbox}

if [ -e $INSTALL_DIR ]
then
    [ -e $INSTALL_DIR/bin/aws-toolbox ] || fail "'$INSTALL_DIR' exists, but '$INSTALL_DIR/bin/aws-toolbox' doesn't? Too afraid to delete..."
    rm -rf $INSTALL_DIR
fi
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

mkdir -p $INSTALL_DIR/pkgs
cd $INSTALL_DIR/pkgs

echo "Downloading packages..."
DOWNLOAD="curl --silent --show-error --fail --remote-name"
$DOWNLOAD http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
$DOWNLOAD http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
$DOWNLOAD http://s3.amazonaws.com/ec2-downloads/CloudWatch-2010-08-01.zip  # URL for latest not available
$DOWNLOAD http://s3.amazonaws.com/ec2-downloads/AutoScaling-2010-08-01.zip # -||-
$DOWNLOAD http://s3.amazonaws.com/ec2-downloads/ElasticLoadBalancing.zip
$DOWNLOAD http://s3.amazonaws.com/rds-downloads/RDSCli.zip
$DOWNLOAD http://s3.amazonaws.com/elasticmapreduce/elastic-mapreduce-ruby.zip
$DOWNLOAD http://s3.amazonaws.com/elasticbeanstalk-us-east-1/resources/elasticbeanstalk-cli.zip
$DOWNLOAD http://s3.amazonaws.com/awsiammedia/public/tools/cli/latest/IAMCli.zip
$DOWNLOAD https://s3.amazonaws.com/cloudformation-cli/AWSCloudFormation-cli.zip

echo "Extracting packages..."
UNZIP="unzip -q"
$UNZIP ec2-api-tools.zip
$UNZIP ec2-ami-tools.zip
$UNZIP CloudWatch-2010-08-01.zip
$UNZIP AutoScaling-2010-08-01.zip
$UNZIP ElasticLoadBalancing.zip
$UNZIP RDSCli.zip
$UNZIP elastic-mapreduce-ruby.zip -d elastic-mapreduce-ruby # tarbomb
$UNZIP elasticbeanstalk-cli.zip -d elasticbeanstalk-cli # tarbomb
$UNZIP IAMCli.zip
$UNZIP AWSCloudFormation-cli.zip
rm *.zip

# Remove versions from directories which have them
for DIR in *
do
    DIR_NOVER=$(echo $DIR | sed 's/[0-9.-]*$//')
    if [ $DIR != $DIR_NOVER ]
    then
        mv $DIR $DIR_NOVER
    fi
done

mkdir -p $INSTALL_DIR/bin
cd $INSTALL_DIR/bin

echo "Installing launcher..."
read -d '' LAUNCHER <<'EOFF' || true
#!/bin/bash
#
# AWS Toolbox launcher
#
# Copyright (c) 2011 Jaka Jancar <jaka@kubje.org>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -eu -o pipefail

CMD=$(basename $0)
AWS_HOME="$(dirname $0)/.."

fail() {
    echo "$0: error: $1" >&2
    exit 1
}

. $HOME/.aws-toolbox/config

# "Autodetect" JAVA_HOME if not set
if [ -z "${JAVA_HOME:-}" ]
then
    if [ $(uname) == 'Darwin' ]
    then
        export JAVA_HOME=$(/usr/libexec/java_home)
    elif [ $(uname) == 'Linux' ]
    then
        export JAVA_HOME=$(dirname $(dirname $(readlink -e $(which java))))
    fi
fi

# Used by ec2 api and ami tools
export EC2_PRIVATE_KEY=$AWS_PRIVATE_KEY
export EC2_CERT=$AWS_CERT
export EC2_URL=https://$AWS_REGION.ec2.amazonaws.com

# Used by cloudwatch, autoscaling, elb, rds
export EC2_REGION=$AWS_REGION

# Create AWS_CREDENTIAL_FILE (used by: cloudwatch, autoscaling, elb, rds, elastic beanstalk, iam)
export AWS_CREDENTIAL_FILE="$HOME/.aws-toolbox/.aws-credential-file.generated"
cat >$AWS_CREDENTIAL_FILE.new.$$ <<EOF
AWSAccessKeyId=$AWS_ACCESS_KEY
AWSSecretKey=$AWS_SECRET_KEY
EOF
mv $AWS_CREDENTIAL_FILE.new.$$ $AWS_CREDENTIAL_FILE

if [ $CMD == 'aws-toolbox' ]
then
    case ${1:-} in
        "")
            cat <<EOF
AWS Toolbox

Usage:

    aws-toolbox test                Check that the installed tools work.

EOF
            exit 0
            ;;
        test)
            check() {
                echo -n "Testing $1... "
                $2 >/dev/null && echo ok || echo failed
            }
        
            check "EC2 API tools"               "ec2-describe-instances"
            check "EC2 AMI tools"               "ec2-upload-bundle --help"
            check "CloudWatch tools"            "mon-describe-alarms"
            check "Auto Scaling tools"          "as-describe-auto-scaling-groups"
            check "ELB tools"                   "elb-describe-lbs"
            check "RDS tools"                   "rds-describe-db-instances"
            check "Elastic MapReduce tools"     "elastic-mapreduce --list"
            check "Elastic Beanstalk tools"     "elastic-beanstalk-describe-applications"
            check "IAM tools"                   "iam-userlistbypath"
            check "CloudFormation tools"        "cfn-describe-stacks"
            ;;
        *)
            echo "Unknown command: '$1'" >&2
            echo "Try just 'aws-toolbox' for usage." >&2
            exit 1
            ;;
    esac
elif [ -e "$AWS_HOME/pkgs/ec2-api-tools/bin/$CMD" ]
then
    EC2_HOME=$AWS_HOME/pkgs/ec2-api-tools \
    $AWS_HOME/pkgs/ec2-api-tools/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/ec2-ami-tools/bin/$CMD" ]
then
    # Different tools need different credentials, and they don't seem to use the env vars.
    # They also mind if you pass some that they don't need. Hence, this complicated block.
    case $CMD in
        ec2-bundle-image)       PARAMS="                                                             --cert $AWS_CERT --privatekey $AWS_PRIVATE_KEY --user $AWS_ACCOUNT_ID" ;;
        ec2-bundle-vol)         PARAMS="                                                             --cert $AWS_CERT --privatekey $AWS_PRIVATE_KEY --user $AWS_ACCOUNT_ID" ;;
        ec2-delete-bundle)      PARAMS="--access-key    $AWS_ACCESS_KEY --secret-key $AWS_SECRET_KEY                                                                      " ;;
        ec2-download-bundle)    PARAMS="--access-key    $AWS_ACCESS_KEY --secret-key $AWS_SECRET_KEY                  --privatekey $AWS_PRIVATE_KEY                       " ;;
        ec2-migrate-bundle)     PARAMS="--access-key    $AWS_ACCESS_KEY --secret-key $AWS_SECRET_KEY --cert $AWS_CERT --privatekey $AWS_PRIVATE_KEY                       " ;;
        ec2-migrate-manifest)   PARAMS="                                                             --cert $AWS_CERT --privatekey $AWS_PRIVATE_KEY                       " ;;
        ec2-unbundle)           PARAMS="                                                                              --privatekey $AWS_PRIVATE_KEY                       " ;;
        ec2-upload-bundle)      PARAMS="--access-key    $AWS_ACCESS_KEY --secret-key $AWS_SECRET_KEY                                                                      " ;;
        cfn-describe-stacks)    PARAMS="--access-key-id $AWS_ACCESS_KEY --secret-key $AWS_SECRET_KEY                                                                      " ;;
        *)                      PARAMS="" ;;
    esac
    
    EC2_HOME=$AWS_HOME/pkgs/ec2-ami-tools \
    $AWS_HOME/pkgs/ec2-ami-tools/bin/$CMD $PARAMS "$@"
elif [ -e "$AWS_HOME/pkgs/CloudWatch/bin/$CMD" ]
then
    AWS_CLOUDWATCH_HOME=$AWS_HOME/pkgs/CloudWatch \
    $AWS_HOME/pkgs/CloudWatch/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/AutoScaling/bin/$CMD" ]
then
    AWS_AUTO_SCALING_HOME=$AWS_HOME/pkgs/AutoScaling \
    $AWS_HOME/pkgs/AutoScaling/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/ElasticLoadBalancing/bin/$CMD" ]
then
    AWS_ELB_HOME=$AWS_HOME/pkgs/ElasticLoadBalancing \
    $AWS_HOME/pkgs/ElasticLoadBalancing/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/RDSCli/bin/$CMD" ]
then
    AWS_RDS_HOME=$AWS_HOME/pkgs/RDSCli \
    $AWS_HOME/pkgs/RDSCli/bin/$CMD "$@"
elif [[ $CMD == 'elastic-mapreduce' ]]
then
    # Create temporary config file
    mkdir -p $HOME/.aws-toolbox/tmp
    EMR_CONFIG="$HOME/.aws-toolbox/tmp/elastic-mapreduce-credentials.$$.json"
    cat >$EMR_CONFIG <<EOF
{
    "access-id": "$AWS_ACCESS_KEY",
    "private-key": "$AWS_SECRET_KEY",
    "key-pair": "$AWS_KEYPAIR_NAME",
    "key-pair-file": "$AWS_KEYPAIR_PRIVATE",
    "region": "$AWS_REGION"
}
EOF
    
    $AWS_HOME/pkgs/elastic-mapreduce-ruby/elastic-mapreduce -c $EMR_CONFIG "$@"
    
    # Remove temporary config file
    rm $EMR_CONFIG
elif [ -e "$AWS_HOME/pkgs/elasticbeanstalk-cli/bin/$CMD" ]
then
    $AWS_HOME/pkgs/elasticbeanstalk-cli/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/IAMCli/bin/$CMD" ]
then
    AWS_IAM_HOME=$AWS_HOME/pkgs/IAMCli \
    $AWS_HOME/pkgs/IAMCli/bin/$CMD "$@"
elif [ -e "$AWS_HOME/pkgs/AWSCloudFormation/bin/$CMD" ]
then
    AWS_CLOUDFORMATION_HOME=$AWS_HOME/pkgs/AWSCloudFormation \
    $AWS_HOME/pkgs/AWSCloudFormation/bin/$CMD "$@"
else
    fail "unknown command: $CMD"
fi
EOFF
echo "$LAUNCHER" >$INSTALL_DIR/bin/aws-toolbox
chmod +x $INSTALL_DIR/bin/aws-toolbox

echo "Setting up symlinks..."
for CMD in ../pkgs/*/bin/*
do
    if [ -x $CMD ] && ! [[ $CMD =~ "service" ]] && ! [[ $CMD =~ ".cmd" ]]
    then
        ln -s aws-toolbox $(basename $CMD)
    fi
done
ln -s aws-toolbox elastic-mapreduce

echo "Creating configuration directory..."
mkdir -p $HOME/.aws-toolbox
cat >$HOME/.aws-toolbox/config.dist <<EOF
# AWS Toolbox config file
#
# To get security credentials, go to
#
#   https://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key
#
# or create them in Identity and Access Management (IAM).
#

### Access Keys

AWS_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxx"
AWS_SECRET_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

### X.509 Certificates
#
# Generate a key and a certificate:
#
#     $ openssl genrsa -out user-cert.key 2048
#     $ openssl req -new -key user-cert.key -out user-cert.csr -batch
#     $ openssl x509 -req -days 1825 -in user-cert.csr -signkey user-cert.key -out user-cert.crt
#     $ rm user-cert.csr
#

AWS_PRIVATE_KEY=$HOME/.aws-toolbox/user-cert.key
AWS_CERT=$HOME/.aws-toolbox/user-cert.crt

### Key Pairs

AWS_KEYPAIR_NAME=user-keypair
AWS_KEYPAIR_PRIVATE=$HOME/.aws-toolbox/user-keypair
AWS_KEYPAIR_PUBLIC=$HOME/.aws-toolbox/user-keypair.pub

### Account Identifiers

AWS_ACCOUNT_ID=xxxxxxxxxxxx
AWS_CANONICAL_USER_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

### Other

# Default region
AWS_REGION=us-east-1
EOF
if ! [ -e $HOME/.aws-toolbox/config ]
then
    cp $HOME/.aws-toolbox/config.dist $HOME/.aws-toolbox/config
fi

cat <<EOF
Done. Next steps:
  - add '$INSTALL_DIR/bin' to your PATH
  - edit '~/.aws-toolbox/config'
  - run 'aws-toolbox test' to check everything is OK
EOF
