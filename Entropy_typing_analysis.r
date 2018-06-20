# Analysis file for Entropy_typing project

## @knitr load_functions

library(data.table)
library(dplyr)
library(ggplot2)
library(Crump)  #for standard error function and Van Selst and Jolicouer outlier elimination


## @knitr load_pre_process

# mturk.txt is the unzipped mturk.txt.zip file
the_data <- fread("~/Desktop/mturk.txt")

# Data-Exclusion

the_data[grepl("[[:punct:]]",substr(the_data$whole_word,nchar(the_data$whole_word),nchar(the_data$whole_word))),]$word_lengths=the_data[grepl("[[:punct:]]",substr(the_data$whole_word,nchar(the_data$whole_word),nchar(the_data$whole_word))),]$word_lengths-1

the_data <- the_data %>%
  filter (
    Letters != " ",                 #removes spaces (just in case they were assigned a letter position)
    !grepl("[[:punct:]]",Letters),  #removes punctuation
    !grepl("[0-9]",Letters),        #removes numbers
    !grepl("[[A-Z]]*",Letters),   #removes Letters that have a capital letter
    ParagraphType == "N",
    PredBigramCorrect == "11",
    IKSIs < 2000
  )

#save(the_data,file='the_data.Rdata')

# Analysis
# Get the means by word length and letter position for each subject
# Use Van Selst and Jolicouer non-recursive_moving procedure from Crump

## @knitr typing_mean_iksis_aov

load("the_data.Rdata")

# get subject means for each letter position and word length

subject_means <- the_data %>%
  group_by(Subject,word_lengths,let_pos) %>%
  summarize(mean_IKSI = mean(non_recursive_moving(IKSIs)$restricted))

#restrict to 1-9 positions and word lengths
subject_means <- subject_means[subject_means$let_pos < 10, ]
subject_means <- subject_means[subject_means$word_lengths < 10 &
                       subject_means$word_lengths > 0, ]

# make sure numbers are factors
subject_means$Subject <- as.factor(subject_means$Subject)
subject_means$let_pos <- as.factor(subject_means$let_pos)
subject_means$word_lengths <- as.factor(subject_means$word_lengths)
#subject_means<-cbind(subject_means,H=rep(uncertainty_df$H,346))

# design is unbalanced so we create a single factor for a one-way ANOVA
position_length <- as.factor(paste0(subject_means$let_pos,subject_means$word_lengths))
subject_means <- cbind(subject_means, Pos_len =position_length)

# Run the ANOVA

#note very slow with aov and > than 50 subjects
#aov.out<-summary(aov(mean_IKSI ~ Pos_len + Error(Subject/Pos_len), subject_means[1:(45*10),]))

library(Rfast)
iksi_matrix <- matrix(subject_means$mean_IKSI,ncol=45,nrow=346,byrow=T)

rm.anova2<-function (y, logged = FALSE) 
{
  dm <- dim(y)
  d <- dim(y)[2]
  n <- dim(y)[1]
  ina <- rep(1:n, each = d)
  xi <- rep(1:d, n)
  yi <- rowmeans(y)
  yj <- colmeans(y)
  yt <- mean(yi)
  sst <- n * sum((yj - yt)^2)
  yi <- rep(yi, each = d)
  yj <- rep(yj, n)
  ssr <- sum((as.vector(t(y)) - yi - yj + yt)^2)
  dft <- d - 1
  dfs <- n - 1
  dfr <- dft * dfs
  mst <- sst/dft
  msr <- ssr/dfr
  stat <- mst/msr
  pvalue <- pf(stat, dft, dfr, lower.tail = FALSE, log.p = logged)
  list(f=stat, p=pvalue, mse=msr, df1=dft, df2=dfr)
}

Exp1_ANOVA <- rm.anova2(iksi_matrix)


## @knitr typing_mean_iksis_plot
# Get the grand means by averaging over subject means
subject_means <- the_data %>%
  group_by(Subject,word_lengths,let_pos) %>%
  summarize(mean_IKSI = mean(non_recursive_moving(IKSIs)$restricted))

sum_data <- subject_means %>%
  group_by(word_lengths,let_pos) %>%
  summarize(mean_IKSIs = mean(mean_IKSI, na.rm = TRUE),
            SE = stde(mean_IKSI))

# plot the data

sum_data <- sum_data[sum_data$let_pos < 10, ]
sum_data <- sum_data[sum_data$word_lengths < 10 &
                       sum_data$word_lengths > 0, ]

sum_data$let_pos<-as.factor(sum_data$let_pos)
sum_data$word_lengths<-as.factor(sum_data$word_lengths)

limits <- aes(ymax = mean_IKSIs + SE, ymin = mean_IKSIs - SE)

ggplot(sum_data,aes(x=let_pos,y=mean_IKSIs,group=word_lengths,color=word_lengths))+
  geom_line()+
  geom_point()+
  geom_errorbar(limits,width=.2)+
  theme_classic()+
  ggtitle("Mean IKSI as a Function of Letter Position and Word Length")

## @knitr typing_mean_iksis_comparisons

# compute all t-tests
all_ts_mat <- matrix(0,ncol=45,nrow=45)
all_ps_mat <- matrix(0,ncol=45,nrow=45)
all_mdiffs <- matrix(0,ncol=45,nrow=45)

for( i in 1:45){
  for( j in 1:45){
    temp_t <- t.test(iksi_matrix[,i],iksi_matrix[,j],paired = T, var.equal = T)
    all_ts_mat[i,j] <- temp_t$statistic
    all_ps_mat[i,j] <- temp_t$p.value
    all_mdiffs[i,j] <- temp_t$estimate
  }
}

# 990 total comparisons

bonferonni_alpha <- .05/990
sig_tests <- all_ps_mat< bonferonni_alpha


all_mdiffs[lower.tri(all_mdiffs)] <- NA
diag(all_mdiffs)<-NA
all_mdiffs <- as.data.frame(all_mdiffs)
all_mdiffs$condition <- seq(1,45)
all_mdiffs <- na.omit(melt(all_mdiffs, 'condition', variable_name='means'))

sig_tests[lower.tri(sig_tests)] <- NA
sig_tests <- as.data.frame(sig_tests)
sig_tests$condition <- seq(1,45)
sig_tests <- na.omit(melt(sig_tests, 'condition', variable_name='means'))

all_mdiffs<-cbind(all_mdiffs,sig=as.numeric(sig_tests$value))

position<-c(1,1:2,1:3,1:4,1:5,1:6,1:7,1:8,1:9)
word_length<-c(1,rep(2,2),
               rep(3,3),
               rep(4,4),
               rep(5,5),
               rep(6,6),
               rep(7,7),
               rep(8,8),
               rep(9,9))

the_labels <- paste(position,word_length,sep="|")
levels(all_mdiffs$variable) <- the_labels
all_mdiffs$condition <- as.factor(all_mdiffs$condition)
levels(all_mdiffs$condition) <- the_labels


ggplot(all_mdiffs, aes(condition, variable)) +
  ggtitle('Mean Absolute Differences') +
  theme_classic(base_size = 7) +
  xlab('Condition') +
  ylab('Condition') +
  geom_tile(aes(fill = sig), color='white') +
  scale_fill_gradient(low = 'darkgrey', high = 'lightgrey', space = 'Lab') +
  theme(axis.text.x=element_text(angle=90),
        axis.ticks=element_blank(),
        axis.line=element_blank(),
        panel.border=element_blank(),
        panel.grid.major=element_line(color='#eeeeee'))+
  geom_text(aes(label=abs(round(value))),size=1.5)



## @knitr letter_uncertainty

letter_freqs <- fread("ngrams1.csv",integer64="numeric")
letter_freqs[letter_freqs==0]<-1

letter_probabilities <- apply(letter_freqs[,2:74],2,function(x){x/sum(x)})

letter_entropies <- apply(letter_probabilities,2,function(x){-1*sum(x*log2(x))})

position<-as.factor(c(1,1:2,1:3,1:4,1:5,1:6,1:7,1:8,1:9))
word_length<-as.factor(c(1,rep(2,2),
               rep(3,3),
               rep(4,4),
               rep(5,5),
               rep(6,6),
               rep(7,7),
               rep(8,8),
               rep(9,9)))

uncertainty_df<-data.frame(H=letter_entropies[11:(11+44)],position,word_length)

#plot

letter_uncertainty_plot1 <- ggplot(uncertainty_df,aes(x=position,y=H,group=word_length,color=word_length))+
  geom_line()+
  geom_point()+
  theme_classic(base_size = 10)+
  theme(plot.title = element_text(size = rel(1)))+
  theme(legend.position="bottom")+
  ggtitle("Letter Uncertainty (H) by Position and Length")

## @knitr letter_uncertainty_by_IKSI

sum_data<-cbind(sum_data,H=uncertainty_df$H)

letter_uncertainty_plot2 <- ggplot(sum_data,aes(x=H,y=mean_IKSIs))+
  geom_point(aes(color=let_pos))+
  geom_smooth(method="lm")+
  #geom_text(aes(x = 2.5, y = 240, label = lm_eqn(lm(mean_IKSIs ~ H, sum_data))), parse = TRUE)+
  theme_classic(base_size = 10)+
  theme(plot.title = element_text(size = rel(1)))+
  theme(legend.position="bottom")+
  ggtitle("Mean IKSI by Letter Uncertainty (H)")

library(ggpubr)

ggarrange(letter_uncertainty_plot1, letter_uncertainty_plot2, 
          labels = c("A", "B"),
          ncol = 2, nrow = 1)

lr_results<-summary(lm(mean_IKSIs~H, sum_data))


subject_means <- the_data %>%
  group_by(Subject,word_lengths,let_pos) %>%
  summarize(mean_IKSI = mean(non_recursive_moving(IKSIs)$restricted))

#restrict to 1-9 positions and word lengths
subject_means <- subject_means[subject_means$let_pos < 10, ]
subject_means <- subject_means[subject_means$word_lengths < 10 &
                                 subject_means$word_lengths > 0, ]

subject_means <- cbind(subject_means,H=rep(uncertainty_df$H,length(unique(subject_means$Subject))))

correlation_data <- subject_means %>%
  group_by(Subject) %>%
  summarize(pearson_r = cor(mean_IKSI,H),
            r_squared = cor(mean_IKSI,H)^2,
            p_value = cor.test(mean_IKSI,H)$p.value)

library(skimr)

skim_with(numeric=list(n=length,mean=mean,sd=sd,SE=stde),append=FALSE)
skim_out<-skim_to_list(correlation_data)

#Means
#p = skim_out$numeric$mean[1]
#r = skim_out$numeric$mean[2]
#r^2 = skim_out$numeric$mean[3]

#SE
#p = skim_out$numeric$SE[1]
#r = skim_out$numeric$SE[2]
#r^2 = skim_out$numeric$SE[3]

## @knitr letter_uncertainty_by_IKSI_dual

categorical_position<-as.character(sum_data$let_pos)
categorical_position[categorical_position=="1"]<-"first"
categorical_position[categorical_position!="first"]<-"other"
categorical_position<-as.factor(categorical_position)
sum_data<-cbind(sum_data,cp=categorical_position)

lr_results_dual<-summary(lm(mean_IKSIs~cp+H, sum_data))

## @knitr letter_uncertainty_bigram

library(dplyr)
library(rlist)
library(ggplot2)
library(bit64)

# GET LETTER POSITION 1 H
# load in the excel file from Norvig:
letter_freqs <- fread("ngrams1.csv",integer64="numeric")
letter_freqs[letter_freqs==0]<-1

get_prob<- function(df) {apply(df,2,function(x){x/sum(x)})}
get_entropies <- function(df){apply(df,2,function(x){-1*sum(x*log2(x))})}

letter_probabilities<-get_prob(letter_freqs[,2:74])
letter_entropies<-get_entropies(letter_probabilities)


let_pos<-c(1,1:2,1:3,1:4,1:5,1:6,1:7,1:8,1:9)
word_lengths<-c(1,rep(2,2),
                rep(3,3),
                rep(4,4),
                rep(5,5),
                rep(6,6),
                rep(7,7),
                rep(8,8),
                rep(9,9))

uncertainty_df<-data.frame(H=letter_entropies[11:(11+44)],let_pos,word_lengths)
uncertainty_df_pos1<-uncertainty_df %>%
  filter(
    let_pos == 1
  )

# GET LETTER POSITION > 1 H
# read in n-gram tsv and clean up
gram_2 <- read.table('2-gram.txt',header=TRUE,sep="\t")
colnames(gram_2)<- scan(file="2-gram.txt",what="text",nlines=1,sep="\t")

# fix NA level
levels(gram_2$`2-gram`)<-c(levels(gram_2$`2-gram`),as.character("NA"))
gram_2[is.na(gram_2$`2-gram`),]$`2-gram` = as.character("NA")


# find and replace missing combos with 0 
allLet<-c("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")
allCombos<-c()
for (i in 1:length(allLet)){
  for(j in 1:length(allLet)){
    allCombos<-c(allCombos,paste(allLet[i],allLet[j],sep=""))
  }
}

missing<-allCombos[!allCombos%in%gram_2$`2-gram`]
missing<-cbind(missing,matrix(0,nrow = length(missing), ncol = ncol(gram_2)-1))
colnames(missing)<-colnames(gram_2)
gram_2<-rbind(gram_2,missing)

# change 0s to 1s
gram_2[gram_2 == 0] <- 1

#split bigrams into letter 1 & 2
letters <- data.frame(do.call('rbind', strsplit(as.character(gram_2$`2-gram`),'',fixed=TRUE)))
colnames(letters)<-c('n-1','n')
names(gram_2)[names(gram_2) == '2-gram'] <- 'bigram'
gram_2<-cbind(letters,gram_2)

#remove unnecessary columns
gram_2<-gram_2[,-4:-12]
gram_2<-gram_2[,-40:-56]
gram_2[,4:39]<-apply(gram_2[,4:39],2,function(x){as.numeric(x)})

# GET ENTROPIES
get_prob<- function(df) {apply(df,2,function(x){x/sum(x)})}
get_entropies <- function(df){apply(df,2,function(x){-1*sum(x*log2(x))})}

letter_probabilities<-(with(gram_2,
                            by(gram_2[,4:39],gram_2[,'n-1'], get_prob,simplify= TRUE)
))

letter_entropies<-lapply(letter_probabilities,get_entropies)
letter_entropies<-list.rbind(letter_entropies)

# column means
means<-colMeans(letter_entropies)

# create data frame
let_pos<-c(2:2,2:3,2:4,2:5,2:6,2:7,2:8,2:9)
word_lengths<-c(rep(2,1),
                rep(3,2),
                rep(4,3),
                rep(5,4),
                rep(6,5),
                rep(7,6),
                rep(8,7),
                rep(9,8))

uncertainty_df<-data.frame(H=means,let_pos,word_lengths)
uncertainty_df<-rbind(uncertainty_df,uncertainty_df_pos1)
#gram_2_test<-merge.data.frame(gram_2,letter_entropies,by.x=('n-1'),by.y=('n-1'))

uncertainty_df$let_pos<-as.factor(uncertainty_df$let_pos)
uncertainty_df$word_lengths<-as.factor(uncertainty_df$word_lengths)

uncertainty_df<-uncertainty_df[order(uncertainty_df$let_pos),]
uncertainty_df<-uncertainty_df[order(uncertainty_df$word_lengths),]

sum_data <- cbind(sum_data,H_bigram=uncertainty_df$H)

# plot

uncertainty_bigram_plot1 <- ggplot(sum_data,aes(x=position,y=H_bigram,group=word_length,color=word_length))+
  geom_line()+
  geom_point()+
  theme_classic(base_size = 10)+
  theme(plot.title = element_text(size = rel(1)))+
  theme(legend.position="bottom")+
  ggtitle("Letter Uncertaint (H, n-1) by Position Length")

# analysis

lr_results_bigram<-summary(lm(mean_IKSIs~H_bigram, sum_data))

uncertainty_bigram_plot2 <-ggplot(sum_data,aes(x=H_bigram,y=mean_IKSIs))+
  geom_point(aes(color=let_pos))+
  geom_smooth(method="lm")+
  #geom_text(aes(x = 2.5, y = 240, label = lm_eqn(lm(mean_IKSIs ~ H, sum_data))), parse = TRUE)+
  theme_classic(base_size = 10)+
  theme(plot.title = element_text(size = rel(1)))+
  theme(legend.position="bottom")+
  ggtitle("Mean IKSIs by Letter Uncertainty (n-1)")

ggarrange(uncertainty_bigram_plot1, uncertainty_bigram_plot2, 
          labels = c("A", "B"),
          ncol = 2, nrow = 1)



