#!/bin/bash
#The Mighty Jenkins Builder Script.

# This script is designed to set up a Jenkins Continuous
# Integration server which will build all of the TEI 
# products automatically from the TEI SVN repository on
# SourceForge. 

# For this to work, you will need a valid license for 
# Oxygen, which is required for building some of the products.

# To use this script, first set up an Ubuntu 12.04 server
# with default configuration (no need to install anything 
# in particular). 

# Next, log into the server and create the directory 
# /usr/share/oxygen, then put a file named licensekey.txt 
# with the nine lines of text of the Oxygen license key 
# (located between the license key start and end markers)
# into that directory.

# Then you can put this script on the server and run it 
# as root to create the server build.

#Note that this should be run as root (with sudo).

#Required location of Oxygen licence.
OxyLicense="/usr/share/oxygen/licensekey.txt"

echo ""
echo "*******************************************"
echo "The purpose of this script is to set up a working
Jenkins Continuous Integration Server which will check
out and build a range of TEI products, including the 
P5 Guidelines (in various formats) and the Roma schema 
generation tool."
echo ""
echo "This script is designed to be run on a fully-updated
install of Ubuntu Precise Pangolin (Ubuntu 12.04). Precise was 
chosen because it is a Long-Term Support edition, and 
will be available for around two years from the time 
of writing the script."
echo ""
echo "The script may work on other versions of Ubuntu,
but only Precise has been tested."
echo "*******************************************"
echo "Press return to continue"
read
echo ""
echo "*******************************************"
echo "In order for Jenkins to build the TEI packages, you will
need to have a registration key for the Oxygen XML Editor. "
echo ""
echo "You must provide a license for Oxygen, in the form of a 
file named licensekey.txt with the nine lines of text of the 
license key (located between the license key start and end 
markers). "
echo ""
echo "This should be placed in /usr/share/oxygen. Create that 
directory if it does not exist."
echo "This script will check for the existence of that file, and
terminate if it does not exist."
echo "*******************************************"
echo ""
echo "Do you want to continue? Press return to continue,
Control+c to stop."
read

echo ""
echo "Entering the Mighty Jenkins Builder Script."

uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "This script must be run as root."; exit 1; }

echo "Running as root: good."
echo ""

if grep -q 12.04 /etc/lsb-release 
then echo "Running on Ubuntu Precise. Good."
else
  echo "This script needs to be run on Ubuntu Precise Server."
  echo "According to /etc/lsb-release, you don't seem to be running that version of Ubuntu."
  echo "The script will now terminate."
  exit
fi
echo ""
#Check for existence of an Oxygen licence key file in /usr/share/oxygen

if [ -f $OxyLicense ];
then echo "Oxygen license is in the right place."
else
  echo "You must provide a license for Oxygen, in the form of a 
file named licensekey.txt with the nine lines of text of the license 
key (located between the license key start and end markers). "
  echo "This should be placed in /usr/share/oxygen. Create that directory if it does not exist."
  echo "The script will now terminate. Run it again when you have installed the Oxygen license key."
  exit
fi

echo ""
echo "Using netstat to check whether any service is currently running on port 8080."
echo ""
netstat -tulpan | grep 8080
if [ $? -eq 0 ] 
then echo "Another service appears to be running on port 8080, which is the default port for Jenkins."
  echo "You can either continue, and then change the port on which Jenkins runs later, or "
  echo "stop now, and move that service to another port."
  echo "Press return to continue, or Control+c to stop."
  read
fi

echo ""
echo "*******************************************"
echo "Throughout the following process, you may be 
asked to agree to various EULAs and licences. Just
agree to everything, by selecting 'OK', 'Yes' etc."
echo "*******************************************"
echo ""

echo "Press return to continue"
read

#Start by installing various fonts. The MS fonts have EULAs, so if we get that 
#bit out of the way, the rest of the install can proceed basically unattended.
echo "We'll start by installing some fonts we need. You'll have to agree to a EULA here."
apt-get -y install msttcorefonts
apt-get -y install ttf-dejavu ttf-arphic-ukai ttf-arphic-uming ttf-baekmuk ttf-junicode ttf-kochi-gothic ttf-kochi-mincho
echo "The Han Nom font is not available in repositories, so we have to download it from SourceForge."
cd /usr/share/fonts/truetype
mkdir hannom
cd hannom
wget -O hannom.zip http://downloads.sourceforge.net/project/vietunicode/hannom/hannom%20v2005/hannomH.zip
unzip hannom.zip
find . -iname "*.ttf" | rename 's/\ /_/g'
rm hannom.zip
fc-cache -f -v

#Now do updates.
echo "Doing system updates before starting on anything else."
apt-get update
apt-get -y upgrade

#Now add the repositories we want.
echo "Backing up repository list."
cp /etc/apt/sources.list /etc/apt/sources.list.bak

#Uncomment partner repos.
echo "Uncommenting partner repositories on sources list."
sed -i -re '/partner/ s/^#//' /etc/apt/sources.list

#First Jenkins
echo "Adding Jenkins repository."
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | apt-key add -
echo "deb http://pkg.jenkins-ci.org/debian binary/" > /etc/apt/sources.list.d/jenkins.list

#Next TEI.
echo "Adding TEI Debian repository. It may take some time to retrieve the key."
gpg --keyserver wwwkeys.pgp.net --recv-keys FEA4973F86A9A497
apt-key add ~/.gnupg/pubring.gpg
echo "deb http://tei.oucs.ox.ac.uk/teideb/binary ./" > /etc/apt/sources.list.d/tei.list

#Now we can start installing packages.
echo "Updating for new repositories."
apt-get update

#We will need a JDK, so we try to install the one to match the default OpenJDK JRE that's installed.
echo "Installing the OpenJDK Java Development Kit."
apt-get -y install openjdk-6-jdk

#We need Maven for the OxGarage install.
echo "Installing the Maven project tool"
apt-get -y install maven2

echo "Installing core packages we need."
apt-get -y install openssh-server libxml2 libxml2-utils devscripts xsltproc debhelper subversion trang &&
echo "Installing curl, required for some tei building stuff."
apt-get -y install curl &&

#TEI packages
echo "Installing TEI packages."
apt-get -y --force-yes install psgml xmlstarlet debiandoc-sgml linuxdoc-tools jing jing-trang-doc libjing-java texlive-xetex &&
apt-get -y --force-yes install trang-java tei-p5-doc tei-p5-database tei-p5-source tei-schema saxon tei-p5-xsl tei-p5-xsl2 tei-p5-xslprofiles tei-roma onvdl tei-oxygen zip &&

#Downloading and installing rnv
echo "Downloading and building rnv (the RelaxNG validator) from SourceForge."
echo "First we need libexpat-dev, on which it depends."
apt-get -y install libexpat-dev
echo "Now we download rnv, build and install it."
wget http://downloads.sourceforge.net/project/rnv/Sources/1.7.10/rnv-1.7.10.zip?r=&ts=1338494052&use_mirror=iweb
unzip rnv-1.7.10.zip
cd rnv-1.7.10
./configure
make
make install

#Setting up configuration for oXygen
#This particular line is very unfortunate, but we apparently have to do it.
chmod a+x /root
mkdir /root/.com.oxygenxml
chmod a+x /root/.com.oxygenxml
mkdir /root/.java
chmod a+x /root/.java
touch  /root/.java/.com.oxygenxml.rk
chmod a+w .com.oxygenxml.rk

#Jenkins
apt-get -y install jenkins

#Configuration for Jenkins
echo "Starting configuration of Jenkins."
echo "Getting the Hudson log parsing rules from TEI SVN."
cd /var/lib/jenkins
svn export https://tei.svn.sourceforge.net/svnroot/tei/trunk/Documents/Editing/Jenkins/hudson-log-parse-rules
chown jenkins hudson-log-parse-rules

echo "Getting all the job data from TEI SVN."
#Don't bring down the config.xml file for now; that contains security settings specific to 
#Sebastian's setup, and will prevent anyone from logging in. We leave the server unsecured,
#and make it up to the user to secure it.
#svn export https://tei.svn.sourceforge.net/svnroot/tei/trunk/Documents/Editing/Jenkins/config.xml
#chown jenkins config.xml
svn export --force https://tei.svn.sourceforge.net/svnroot/tei/trunk/Documents/Editing/Jenkins/jobs/ jobs
chown -R jenkins jobs
echo "Installing Jenkins plugins."
cd plugins
wget --no-check-certificate http://updates.jenkins-ci.org/latest/copyartifact.hpi
chown jenkins copyartifact.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/emotional-hudson.hpi
chown jenkins emotional-hudson.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/greenballs.hpi
chown jenkins greenballs.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/jobConfigHistory.hpi
chown jenkins jobConfigHistory.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/plot.hpi
chown jenkins plot.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/log-parser.hpi
chown jenkins log-parser.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/scp.hpi
chown jenkins scp.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/WebSVN2.hpi
chown jenkins WebSVN2.hpi
wget --no-check-certificate http://updates.jenkins-ci.org/latest/PrioritySorter.hpi
chown jenkins PrioritySorter.hpi

echo "Stopping Jenkins server, so that we can reconfigure all the jobs a little."
/etc/init.d/jenkins stop

#Reconfigure Jinks jobs with user's email, and adding priority settings if necessary.
#NOTE: Avoiding this, because you need to set up a whole host of Jenkins config files
#in order to make emailing work.
#echo "If you want Jenkins to notify you when a build fails, please enter your email address now:"
#read email
echo "Configuring job priorities settings."

cd /var/lib/jenkins
svn export https://tei.svn.sourceforge.net/svnroot/tei/trunk/Documents/Editing/Jenkins/jenkins_job_config.xsl
chown jenkins jenkins_job_config.xsl

echo "Running transformations on job configurations."
saxon -s:/var/lib/jenkins/jobs/OxGarage/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/OxGarage/config.xml jobPriority=90 email=
saxon -s:/var/lib/jenkins/jobs/Roma/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/Roma/config.xml jobPriority=90 email=
saxon -s:/var/lib/jenkins/jobs/Stylesheets/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/Stylesheets/config.xml jobPriority=100 email=
saxon -s:/var/lib/jenkins/jobs/Stylesheets1/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/Stylesheets1/config.xml jobPriority=90 email=
saxon -s:/var/lib/jenkins/jobs/TEIP5/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/TEIP5/config.xml jobPriority=10 email=
saxon -s:/var/lib/jenkins/jobs/TEIP5-Documentation/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/TEIP5-Documentation/config.xml jobPriority=10 email=
saxon -s:/var/lib/jenkins/jobs/TEIP5-Test/config.xml -xsl:/var/lib/jenkins/jenkins_job_config.xsl -o:/var/lib/jenkins/jobs/TEIP5-Test/config.xml jobPriority=10 email=

echo "Starting the Jenkins server."
/etc/init.d/jenkins start

#NOTE: No need for the lines below because the Priority Sorter plugin should handle it.
#echo "Triggering the Stylesheet job. It needs to be completed before other P5 builds will succeed."
#wget http://localhost:8080/job/Stylesheets/build > /dev/null
#echo "Stylesheets build has been triggered."

echo "OK, we should be done. Now you have to:"
echo "Go to the Jenkins interface on http://[this_computer_ip]:8080, and set up authentication. Read the Jenkins documentation for help with this."
echo "If some builds fail initially, it may be simply due to sequencing and timing. Trigger the Stylesheets build, and when that's completed, trigger the TEIP5-Test build."
echo "That's it!"
echo "Press return to exit."
read
exit

