#!/bin/bash
alias userGen='userGen'
alias domainPref='domainPref'
alias mentorAllocation='mentorAllocation'
alias submitTask='submitTask'
alias displayStatus='displayStatus'
alias deRegister='deRegister'
alias setQuiz='setQuiz'

userGen() {
    sudo useradd -m core
    sudo mkdir /home/core/mentors /home/core/mentees
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        roll=$(echo "$line" | awk '{print $2}')
        sudo useradd -m -d /home/core/mentees/"$roll" "$roll"
        sudo touch /home/core/mentees/"$roll"/domain_pref.txt
        sudo touch /home/core/mentees/"$roll"/task_completed.txt
        sudo touch /home/core/mentees/"$roll"/task_submitted.txt
    done < menteeDetails.txt


    sudo mkdir /home/core/mentors/Webdev /home/core/mentors/Appdev /home/core/mentors/Sysad
    while IFS= read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        domain=$(echo "$line" | awk '{print $2}')
        capacity=$(echo "$line" | awk '{print $3}')
        sudo useradd -m -d /home/core/mentors/"$domain"/"$name" "$name"
        sudo mkdir /home/core/mentors/"$domain"/"$name"/submittedTasks
        sudo mkdir /home/core/mentors/"$domain"/"$name"/submittedTasks/task1
        sudo mkdir /home/core/mentors/"$domain"/"$name"/submittedTasks/task2
        sudo mkdir /home/core/mentors/"$domain"/"$name"/submittedTasks/task3
        sudo touch /home/core/mentors/"$domain"/"$name"/allocatedMentees.txt
    done < mentorDetails.txt


    sudo chmod -R 755 /home/core
    sudo chown -R core:core /home/core
    sudo chmod -R 750 /home/core/mentees
    sudo chmod -R 750 /home/core/mentors
    sudo touch /home/core/mentees_domain.txt
    sudo chmod 622 /home/core/mentees_domain.txt
}



domainPref() {
    read -p "Enter your roll number: " roll
    read -p "Enter your domain preferences (1-3, separated by spaces): " domains
    echo "$domains" | sed 's/ /\n/g' > /home/core/mentees/"$roll"/domain_pref.txt
    echo "$roll $domains" >> /home/core/mentees_domain.txt
    for domain in $domains; do
        sudo mkdir /home/core/mentees/"$roll"/"$domain"
    done
}



mentorAllocation() {
    
    while IFS= read -r line; do
        roll=$(echo "$line" | awk '{print $1}')
        domains=$(echo "$line" | awk '{print $2}' | sed 's/->/ /g')

        for domain in $domains; do
            mentor=$(awk -v domain="$domain" -v capacity="999999" '$2 == domain && $3 < capacity {capacity = $3; name = $1} END {print name}' mentorDetails.txt)
            if [ -n "$mentor" ]; then
                echo "$roll" >> /home/core/mentors/"$domain"/"$mentor"/allocatedMentees.txt
                break
            fi
        done
    done < mentees_domain.txt
}



submitTask() {
    if [ "$EUID" -ne 0 ]; then
       
        read -p "Enter your roll number: " roll
        read -p "Enter the task number (1-3): " task_num
        read -p "Enter the domain: " domain
        echo "Task $task_num (Domain: $domain)" >> /home/core/mentees/"$roll"/task_submitted.txt
        sudo mkdir /home/core/mentees/"$roll"/"$domain"/task"$task_num"
        read -p "Enter the file(s) to submit (separated by spaces): " files
        for file in $files; do
            sudo cp "$file" /home/core/mentees/"$roll"/"$domain"/task"$task_num"/
        done

    else
        read -p "Enter your name: " mentor_name
        read -p "Enter your domain: " domain
        for task_dir in /home/core/mentors/"$domain"/"$mentor_name"/submittedTasks/task*; do
            task=$(basename "$task_dir")
            while IFS= read -r roll; do
                mentee_task_dir="/home/core/mentees/$roll/$domain/$task"
                if [ -d "$mentee_task_dir" ]; then
                    sudo ln -s "$mentee_task_dir" "$task_dir"
                    if [ "$(ls -A "$mentee_task_dir")" ]; then
                        echo "$roll: Task $task completed" >> /home/core/mentees/"$roll"/task_completed.txt
                    fi
                fi
            done < /home/core/mentors/"$domain"/"$mentor_name"/allocatedMentees.txt
        done
    fi
}



displayStatus() {
    total_mentees=$(wc -l < menteeDetails.txt)
    domain=""
    if [ "$#" -eq 1 ]; then
        domain="$1"
    fi

    for task_num in {1..3}; do
        completed_mentees=0
        echo "Task $task_num:"
        if [ -n "$domain" ]; then
            echo "Domain: $domain"
        fi

        while IFS= read -r roll; do
            mentee_task_dir="/home/core/mentees/$roll"
            if [ -n "$domain" ]; then
                mentee_task_dir="$mentee_task_dir/$domain/task$task_num"
            else
                mentee_task_dir="$mentee_task_dir/*/task$task_num"
            fi

            if [ "$(ls -A "$mentee_task_dir" 2>/dev/null)" ]; then
                completed_mentees=$((completed_mentees + 1))
                echo "$roll"
            fi
        done < menteeDetails.txt

        percentage=$((completed_mentees * 100 / total_mentees))
        echo "$percentage% of mentees submitted Task $task_num"
        echo
    done
}

source ~/.bashrc
