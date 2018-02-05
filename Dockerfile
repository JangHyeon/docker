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


##########################################
################# git ####################

RUN yum install -y git
#RUN git ls-files -s | awk '/12000/{print $4}'

##########################################

##########################################
################# php ####################

# 저장소 갱신
RUN yum install -y epel-release
RUN rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
RUN rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm
RUN rpm -Uvh http://repo.mysql.com/mysql-community-release-el6-5.noarch.rpm
RUN yum --enablerepo=remi-php71 install -y php php-fpm php-gd php-mbstring php-mcrypt php-mysql php-json php-soap php-xml php-xmlrpc php-devel php-pecl-zip

RUN echo "date.timezone = Asia/Seoul" >> /etc/php.ini
RUN echo "cgi.fix_pathinfo = 0" >> /etc/php.ini

RUN sed -i \
	-e "s/user = apache/user = $WEB_ID/g" \
	-e "s/group = apache/group = $WEB_ID/g" \

	-e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
	-e "s/;listen.mode = 0660/listen.mode = 0666/g" \
    -e "s/;listen.owner = nobody/listen.owner = $WEB_ID/g" \
    -e "s/;listen.group = nobody/listen.group = $WEB_ID/g" \
#	-e "s/;listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php-fpm.sock/g" \
	/etc/php-fpm.d/www.conf

##########################################
################# nginx ##################

# yum 저장소 추가
COPY nginx/nginx.repo /etc/yum.repos.d/nginx.repo

# nginx image-filter 추가
RUN yum install -y nginx nginx-module-image-filter

# nginx 경로 생성
RUN mkdir /home/sessions
RUN mkdir /home/FILE_LOG
RUN mkdir /home/UPLOAD_FILE
RUN mkdir /home/core
RUN mkdir /home/www
COPY index.php /home/www/index.php

RUN chown -R $WEB_ID:$WEB_ID /home/*


##########################################
######### nginx & php-fpm 연동 ###########

RUN rm -f /etc/nginx/nginx.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/vhosts /etc/nginx/vhosts

# nginx 설정
RUN sed -i -e "s/user apache;/user $WEB_ID;/g" /etc/nginx/nginx.conf
#RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# nginx 권한 수정
RUN chown -R $WEB_ID:$WEB_ID /etc/nginx
RUN chown -R $WEB_ID:$WEB_ID /var/log/nginx

##########################################
############## 컴포저 설치 ###############
RUN curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin/
RUN sudo ln -s /usr/local/bin/composer.phar /usr/local/bin/composer

# 윈도우 기반에선 setting shared drives 설정 필요
VOLUME ["/home/www", "/home/core", "/home/FILE_LOG", "/home/UPLOAD_FILE", "/etc/nginx/vhosts"]

# 포트 설정
EXPOSE 80 443

COPY start.sh /
CMD ["/bin/bash", "/start.sh"]

#End
