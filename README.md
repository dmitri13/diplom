
1. Структура диплома  

![struc](https://github.com/dmitri13/diplom/blob/main/image/structure.png)

ansible - скрипты ansible для поднятия все сервисов на VM - пока примерно, еще не все тестировал  
bastion - терраформ для поднятия бастиона   
 ansible_ssh - скрипты для создания ssh ключа на бастионе и копирования их на хост  
service - терраформ для поднятия всех VM  

Вопросы, как нужно будет показывать работоспособность всех сервисов?  
должны ли какие-то VM кроме bastiona иметь внешний ip?

