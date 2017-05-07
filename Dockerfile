#Dockerfile

# 어떤 이미지로 부터 새로운 이미지를 생성할지 지정
FROM centos:centos6.9

# Dockerfile을 생성/관리하는 사람
MAINTAINER lkjlki<lkjlki@naver.com>

# GPG키 값이 폐기되어서 갱신
RUN rpm --import /etc/pki/rpm-gpg/RPM*

# 한국 서버시간으로 변경
RUN ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

##########################################
################# ssh ####################

# yum 저장소 갱신 & openssh server 설치
RUN yum update -y
RUN yum install -y openssh-server

# SSH키 생성
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN sed -ri 's/session    required     pam_loginuid.so/#session    required     pam_loginuid.so/g' /etc/pam.d/sshd
RUN mkdir -p /root/.ssh && chown root.root /root && chmod 700 /root/.ssh

# root 비밀번호 변경 '123456'
RUN echo 'root:123456' | chpasswd

# 웹서비스용 계정 추가
ENV WEB_ID www-data

RUN adduser $WEB_ID
RUN echo "$WEB_ID:123456" | chpasswd

# 가상머신에 오픈할 포트
EXPOSE 22

# 컨테이너에서 실행될 명령을 지정
CMD /usr/sbin/sshd -D

##########################################
################# git ####################

RUN yum install -y git

##########################################
################# nginx ##################

# yum 저장소 추가
ADD nginx/nginx.repo /etc/yum.repos.d/nginx.repo

# nginx image-filter 추가
RUN yum install -y nginx nginx-module-image-filter

# nginx 설정
RUN sed -i -e "s/user  nginx;/user  $WEB_ID;/g" /etc/nginx/nginx.conf
RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# nginx 권한 수정
RUN chown -R $WEB_ID:$WEB_ID /etc/nginx
RUN chown -R $WEB_ID:$WEB_ID /var/log/nginx

RUN mkdir /home/sessions
RUN mkdir /home/FILE_LOG
RUN mkdir /home/UPLOAD_FILE
RUN mkdir /home/core
RUN mkdir /home/www
ADD index.php /home/www/index.php

RUN chown -R $WEB_ID:$WEB_ID /home/*

# 윈도우 기반에선 setting shared drives 설정 필요
VOLUME ["/home/www", "/home/core", "/home/FILE_LOG", "/home/UPLOAD_FILE", "/etc/nginx"]

EXPOSE 443
EXPOSE 80

WORKDIR /usr/sbin
CMD ["nginx"]


##########################################
################# php ####################

# 저장소 갱신
RUN yum install -y epel-release
RUN rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
RUN rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
RUN rpm -Uvh http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm
RUN yum --enablerepo=remi-php71 install -y php php-fpm php-gd php-mbstring php-mcrypt php-mysql php-json php-soap php-xml php-xmlrpc

RUN echo "date.timezone = Asia/Seoul" >> /etc/php.ini
RUN echo "cgi.fix_pathinfo = 0" >> /etc/php.ini

RUN sed -i \
	-e "s/user = apache/user = $WEB_ID/g" \
	-e "s/group = apache/group = $WEB_ID/g" \
	/etc/php-fpm.d/www.conf


##########################################
######### nginx & php-fpm 연동 ###########

ADD nginx/nginx.conf /etc/nginx/nginx.conf
ADD nginx/vhosts /etc/nginx/vhosts

RUN sed -i \
	-e "s/user apache;/user $WEB_ID;/g" \
	/etc/nginx/nginx.conf

#End
