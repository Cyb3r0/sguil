proc QryBuild {} {
    global RETURN_FLAG 
    global  tableColumnArray tableList funcList
    set RETURN_FLAG 0

    # Grab the current pointer locations
    set xy [winfo pointerxy .]
    
    # Create the window
    set qryBldWin [toplevel .qryBldWin]
    wm title $qryBldWin "Query Builder"
    wm geometry $qryBldWin +[lindex $xy 0]+[lindex $xy 1]
    
    # Create some arrays for the lists
    set mlst [list Tables Functions]
    set funcList(main) [list Common Strings Comparison Logical DateTime]
    set funcList(Common) [list INET_ATON() LIMIT LIKE() AND OR NOT]
    set funcList(Strings) [list LIKE REGEXP RLIKE]
    set funcList(Logical) [list AND OR NOT BETWEEN()]
    set funcList(Comparison) [list = != < > <=>]
    set funcList(DateTime) [list TO_DAYS() UNIX_TIMESTAMP() UTC_TIMESTAMP()]
    foreach tableName $tableList {
	set funcList($tableName) $tableColumnArray($tableName)
    }
    
    # Main Frame
    set mainFrame [frame $qryBldWin.mFrame -background #dcdcdc -borderwidth 1]

    
    
    set editFrame [frame $mainFrame.eFrame -background black -borderwidth 1]
      set editBox [scrolledtext $editFrame.eBox -textbackground white -vscrollmode dynamic \
		-sbwidth 10 -hscrollmode none -wrap word -visibleitems 60x10 -textfont ourFixedFont \
		-labeltext "Edit Where Clause"]
      $editBox insert end "WHERE event.sid = sensor.sid AND  LIMIT 500"
      $editBox mark set insert "end -11 c"
      set bb [buttonbox $mainFrame.bb]
      $bb add Submit -text "Submit" -command "set RETURN_FLAG 1"
      $bb add Cancel -text "Cancel" -command "set RETURN_FLAG 0"
      #pack $bb -side top -fill x -expand true

    set mainBB1 [buttonbox $editFrame.mbb1 -padx 0 -pady 0 -orient vertical]
      foreach logical $funcList(Logical) {
	  set command "$editBox insert insert \"$logical \""
	  $mainBB1 add $logical -text $logical -padx 0 -pady 0 -command "$command"
      }
    set mainBB2 [buttonbox $editFrame.mbb2 -padx 0 -pady 0 -orient vertical]
      foreach comparison $funcList(Comparison) {
	  set command "$editBox insert insert \"$comparison \""
	  $mainBB2 add $comparison -text $comparison -padx 0 -pady 0 -command "$command"
      }
      pack $mainBB1 -side left -fill y
      pack $editBox -side left -fill both -expand true
      pack $mainBB2 -side left -fill y

    set selectFrame [frame $mainFrame.sFrame -background black -borderwidth 1]
      set catList [scrolledlistbox $selectFrame.cList -labeltext Categories \
	      -selectioncommand "updateItemList $selectFrame" -sbwidth 10\
	      -labelpos n -vscrollmode static -hscrollmode dynamic \
	      -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
      set metaList [scrolledlistbox $selectFrame.mList -labeltext Meta -sbwidth 10\
	      -selectioncommand "updateCatList $selectFrame" \
	      -hscrollmode dynamic \
	      -labelpos n -vscrollmode static \
	      -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
      set itemList [scrolledlistbox $selectFrame.iList -hscrollmode dynamic -sbwidth 10\
	     -dblclickcommand "addToEditBox $editBox $selectFrame" \
	     -scrollmargin 5 -labeltext "Items" \
	     -labelpos n -vscrollmode static -hscrollmode static\
	     -visibleitems 20x10 -foreground darkblue -textbackground lightblue]
  
      pack $metaList $catList $itemList -side left -fill both -expand true
      iwidgets::Labeledwidget::alignlabels $metaList $catList $itemList
    
    pack $editFrame -side top -fill both -expand yes
    #pack  $mainBB1 $mainBB2 -side top -fill none -expand false
    pack  $selectFrame $bb -side top -fill both -expand true -pady 1
    eval $metaList insert 0 $mlst
    pack $mainFrame -side top -pady 1

    




    tkwait variable RETURN_FLAG
    set returnWhere 0
    if {$RETURN_FLAG} {
	set returnWhere "[$editBox get 0.0 end]"
	puts $returnWhere
    }
    destroy $qryBldWin
    return $returnWhere  
}


proc updateCatList { selectFrame } {
    global tableList funcList metaSelection
     
    $selectFrame.cList delete 0 end
    #$selectFrame.cList delete entry 0 end
    $selectFrame.iList delete 0 end
    
    set sel [$selectFrame.mList getcurselection]
    set metaSelection $sel
    if {$sel == "Tables"} { 
	eval $selectFrame.cList insert 0 $tableList
    } else {
	eval $selectFrame.cList insert 0 $funcList(main)
    }
}
    
proc updateItemList { selectFrame} {
    global funcList catSelection
    
    $selectFrame.iList delete 0 end
    #$selectFrame.iList delete entry 0 end
    
    eval set sel [$selectFrame.cList getcurselection]
    set catSelection $sel
    eval $selectFrame.iList insert 0 $funcList($sel)
}

proc addToEditBox { editBox selectFrame } {
    global catSelection metaSelection
    set addText [lindex [$selectFrame.iList getcurselection] 0]
    
    #if Meta is set to table, prepend tablename. to the item
    if {$metaSelection == "Tables"} {
	set addText "$catSelection.$addText"
    }
    
    $editBox insert insert "$addText "
}


