#
#  This script currently not working - awaiting changes to webAPI (update: 11/3/2020)

#  Source this script to run the code and view the Shiny app of Bering Sea SST
#  Date created: June 5 2020
#  Author: Jordan.Watson@noaa.gov


#  Load packages
library(shiny)
library(tidyverse)
library(lubridate)
library(cowplot)
library(magick)
library(httr)

#  Load 508 compliant NOAA colors
OceansBlue1='#0093D0'
OceansBlue2='#0055A4' # rebecca dark blue
CoralRed1='#FF4438'
SeagrassGreen1='#93D500'
SeagrassGreen4='#D0D0D0' # This is just grey
UrchinPurple1='#7F7FFF'
WavesTeal1='#1ECAD3'

#  Assign colors to different time series.
current.year.color <- OceansBlue1
last.year.color <- WavesTeal1
mean.color <- "black"

#  Set default plot theme
theme_set(theme_cowplot())

#  Specify legend position coordinates
mylegx <- 0.525
mylegy <- 0.865

#  Specify NOAA logo position coordinates
mylogox <- 0.045
mylogoy <- 0.305

#  Pull data from AKFIN using public web API
#  Create a series of dummy dates (the year 2000 was chosen) that allows all years to be plotted along the same x-axis
data <- httr::content(httr::GET('https://apex.psmfc.org/akfin/data_marts/akmp/GET_TIME_SERIES_REGIONAL_AVG_TEMPS'), type = "text/csv") %>% 
    rename_all(tolower) %>% 
    mutate(read_date=as.Date(read_date,format="%m/%d/%Y"),
           julian=as.numeric(julian),
           esr_region=fct_relevel(esr_region,"NBS","EBS","EGOA","WGOA","SEAK Inside"),
           esr_region2=case_when(
               esr_region=="EBS" ~ "Eastern Bering Sea Shelf",
               esr_region=="NBS" ~ "Northern Bering Sea Shelf",
               esr_region=="EGOA" ~ "Eastern Gulf of Alaska",
               esr_region=="WGOA" ~ "Western Gulf of Alaska",
               esr_region=="CGOA" ~ "Central Gulf of Alaska"),
           esr_region2=fct_relevel(as.factor(esr_region2),"Northern Bering Sea Shelf","Eastern Bering Sea Shelf","Western Gulf of Alaska","Eastern Gulf of Alaska"),
           month=month(read_date),
           day=day(read_date),
           newdate=as.Date(ifelse(month==12,as.character(as.Date(paste("1999",month,day,sep="-"),format="%Y-%m-%d")),
                                  as.character(as.Date(paste("2000",month,day,sep="-"),format="%Y-%m-%d"))),format("%Y-%m-%d")),
           year2=ifelse(month==12,year+1,year)) %>% 
    arrange(read_date)

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    title="Sea Surface Temperatures, Bering Sea",

           plotOutput("distPlot")
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$distPlot <- renderPlot({
        # generate bins based on input$bins from ui.R
        

        #  Set year criteria to automatically identify the current and previous years
        current.year <- max(data$year)
        last.year <- current.year-1
        mean.years <- 2003:2012
        mean.lab <- "Mean 2003-2012"
        
        #  Create plotting function that will allow selection of 2 ESR regions
        myplotfun <- function(region1,region2){
            mylines_base <- ggplot() +
                geom_line(data=data %>% filter(year2<last.year & esr_region%in%(c(region1,region2))),
                          aes(newdate,meansst,group=factor(year2),col='mygrey'),size=0.3) +
                geom_line(data=data %>% filter(year2==last.year & esr_region%in%(c(region1,region2))),
                          aes(newdate,meansst,color='last.year.color'),size=0.75) +
                geom_line(data=data %>% 
                              filter(year%in%mean.years & esr_region%in%(c(region1,region2))) %>% 
                              group_by(esr_region2,newdate) %>% 
                              summarise(meantemp=mean(meansst,na.rm=TRUE)),
                          aes(newdate,meantemp,col='mean.color'),size=0.5) +
                geom_line(data=data %>% filter(year2==current.year & esr_region%in%(c(region1,region2))),
                          aes(newdate,meansst,color='current.year.color'),size=0.95) +
                facet_wrap(~esr_region2,ncol=2) + 
                scale_color_manual(name="",
                                   breaks=c('current.year.color','last.year.color','mygrey','mean.color'),
                                   values=c('current.year.color'=current.year.color,'last.year.color'=last.year.color,'mygrey'=SeagrassGreen4,'mean.color'=mean.color),
                                   labels=c(current.year,last.year,paste0('2002-',last.year-1),mean.lab)) +
                ylab("Mean Sea Surface Temperature (C)") + 
                xlab("") +
                scale_x_date(date_breaks="1 month",
                             date_labels = "%b",
                             expand = c(0.025,0.025)) + 
                theme(legend.position=c(mylegx,mylegy),
                      legend.text = element_text(size=8,family="sans"),
                      legend.background = element_rect(fill="white"),
                      legend.title = element_blank(),
                      strip.text = element_text(size=10,color="white",family="sans",face="bold"),
                      strip.background = element_rect(fill=OceansBlue2),
                      axis.title = element_text(size=10,family="sans"),
                      axis.text = element_text(size=10,family="sans"),
                      panel.border=element_rect(colour="black",size=0.75),
                      axis.text.x=element_text(color=c("black",NA,NA,"black",NA,NA,"black",NA,NA,"black",NA,NA,NA)),
                      legend.key.size = unit(0.35,"cm")) 
            
            ggdraw(mylines_base) +
                draw_image("fisheries_header_logo_jul2019.png",scale=0.2,x=mylogox,y=mylogoy,hjust=0.35) +
                annotate("text",x=0.115,y=0.045,label=paste0("Contact: Jordan.Watson@noaa.gov, Alaska Fisheries Science Center, NOAA Fisheries (data: JPL MUR SST, ",format(Sys.Date(),"%m-%d-%Y"),")"),
                         hjust=0.1,size=2.59,family="sans",fontface=2,color=OceansBlue2)
        }
        
        #png(paste0("figure_output/SST_Twitter_",format(Sys.Date(),"%Y_%m_%d"),".png"),width=6,height=3.375,units="in",res=200)
        myplotfun("NBS","EBS")
        #dev.off()
        

    })
}

# Run the application 
shinyApp(ui = ui, server = server)







