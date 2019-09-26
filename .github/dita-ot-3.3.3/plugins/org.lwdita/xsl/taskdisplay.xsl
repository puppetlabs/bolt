<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:related-links="http://dita-ot.sourceforge.net/ns/200709/related-links"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="related-links dita2html ditamsg xs">
  
  <xsl:param name="GENERATE-TASK-LABELS" select="'NO'"/>
    
  <xsl:template match="*[contains(@class,' task/taskbody ')]" name="topic.task.taskbody">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:apply-templates select="preceding-sibling::*[contains(@class,' topic/abstract ')]" mode="outofline"/>
      <xsl:apply-templates select="preceding-sibling::*[contains(@class,' topic/shortdesc ')]" mode="outofline"/>
      <xsl:if test="not(*[contains(@class,' task/prereq ')])">
        <xsl:apply-templates select="following-sibling::*[contains(@class,' topic/related-links ')]" mode="prereqs"/>
      </xsl:if>
      <xsl:apply-templates/>
      <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </div>  
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/prereq ')]" mode="get-output-class">p</xsl:template>
  <xsl:template match="*[contains(@class,' task/prereq ')]" name="topic.task.prereq">
    <div class="p">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="gen-toc-id"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <xsl:apply-templates select="." mode="dita2html:section-heading">
        <!--xsl:with-param name="deftitle"></xsl:with-param-->
        <xsl:with-param name="defaulttitle"></xsl:with-param>
      </xsl:apply-templates>
      <!-- Title is not allowed now, but if we add it, make sure it is processed as in section -->
      <xsl:apply-templates select="*[not(contains(@class,' topic/title '))] | text() | comment() | processing-instruction()"/>
      
      <!-- Insert pre-req links - after prereq section -->
      <xsl:apply-templates select="../following-sibling::*[contains(@class,' topic/related-links ')]" mode="prereqs"/>
      
      <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
      <xsl:if test="$link-top-section='yes'"> <!-- optional return to top - not used -->
        <para align="left">
          <link href="#TOP">
            <!--xsl:value-of select="$deftxt-linktop"/-->
            <xsl:call-template name="getVariable">
              <xsl:with-param name="id" select="'Return to Top'"/>
            </xsl:call-template>
          </link>
        </para>
      </xsl:if>
    </div>
  </xsl:template>
  
  <xsl:template match="*" mode="make-steps-compact">
    <xsl:choose>
      <!-- expand the list when one of the steps has any of these: "*/*" = step context -->
      <xsl:when test="*/*[contains(@class,' task/info ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/stepxmp ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/tutorialinfo ')]">yes</xsl:when>
      <xsl:when test="*/*[contains(@class,' task/stepresult ')]">yes</xsl:when>
      <xsl:otherwise>no</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps ')]" name="topic.task.steps">
   <!-- If there's one of these elements somewhere in a step, expand the whole step list -->
    <xsl:variable name="step_expand"> <!-- set & save step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="common-processing-within-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
      <xsl:with-param name="list-type" select="'ol'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps ') or contains(@class,' task/steps-unordered ')]"
                mode="common-processing-within-steps">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type">
      <xsl:choose>
        <xsl:when test="contains(@class,' task/steps ')">ol</xsl:when>
        <xsl:otherwise>ul</xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_procedure'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
    <xsl:choose>
      <xsl:when test="*[contains(@class,' task/step ')] and not(*[contains(@class,' task/step ')][2])">
        <!-- Single step. Process any stepsection before the step (cannot appear after). -->
        <xsl:apply-templates select="*[contains(@class,' task/stepsection ')]"/>
        <xsl:apply-templates select="*[contains(@class,' task/step ')]" mode="onestep">
          <xsl:with-param name="step_expand" select="$step_expand"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="not(*[contains(@class,' task/stepsection ')])">
        <xsl:apply-templates select="." mode="step-elements-with-no-stepsection">
          <xsl:with-param name="step_expand" select="$step_expand"/>
          <xsl:with-param name="list-type" select="$list-type"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="*[1][contains(@class,' task/stepsection ')] and not(*[contains(@class,' task/stepsection ')][2])">
        <!-- Stepsection is first, no other appearances -->
        <xsl:apply-templates select="*[contains(@class,' task/stepsection ')]"/>
        <xsl:apply-templates select="." mode="step-elements-with-no-stepsection">
          <xsl:with-param name="step_expand" select="$step_expand"/>
          <xsl:with-param name="list-type" select="$list-type"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <!-- Stepsection elements mixed in with steps -->
        <xsl:apply-templates select="." mode="step-elements-with-stepsection">
          <xsl:with-param name="step_expand" select="$step_expand"/>
          <xsl:with-param name="list-type" select="$list-type"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="*" mode="step-elements-with-no-stepsection">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type"/>
    <xsl:call-template name="setaname"/>
    <xsl:element name="{$list-type}">
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates select="*[contains(@class,' task/step ')]" mode="steps">
        <xsl:with-param name="step_expand" select="$step_expand"/>
      </xsl:apply-templates>
    </xsl:element>  
  </xsl:template>
  
  <xsl:template match="*" mode="step-elements-with-stepsection">
    <xsl:param name="step_expand"/>
    <xsl:param name="list-type"/>
    <xsl:for-each select="*">
      <xsl:choose>
        <xsl:when test="contains(@class,' task/stepsection ')">
          <xsl:apply-templates select="."/>
        </xsl:when>
        <xsl:when test="contains(@class,' task/step ') and preceding-sibling::*[1][contains(@class,' task/step ')]">
          <!-- Do nothing, was pulled in through recursion -->
        </xsl:when>
        <xsl:otherwise>
          <!-- First step in a series of steps -->
          <xsl:element name="{$list-type}">
            <xsl:if test="$list-type='ol' and preceding-sibling::*[contains(@class,' task/step ')]">
              <!-- Restart numbering for ordered steps that were interrupted by stepsection.
                   The start attribute is valid in XHTML 1.0 Transitional, but not for XHTML 1.0 Strict.
                   It is possible (preferable) to keep stepsection within an <li> and use CSS to
                   fix numbering, but with testing in March of 2009, this does not work in IE. 
                   It is possible in Firefox 3. -->
              <xsl:attribute name="start"><xsl:value-of select="count(preceding-sibling::*[contains(@class,' task/step ')])+1"/></xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="." mode="steps">
              <xsl:with-param name="step_expand" select="$step_expand"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="following-sibling::*[1][contains(@class,' task/step ')]" mode="sequence-of-steps">
              <xsl:with-param name="step_expand" select="$step_expand"/>
            </xsl:apply-templates>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="*" mode="sequence-of-steps">
    <xsl:param name="step_expand"/>
    <xsl:apply-templates select="." mode="steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="following-sibling::*[1][contains(@class,' task/step ')]" mode="sequence-of-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepsection ')]">
    <para>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates/>
    </para>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/steps-unordered ')]" name="topic.task.steps-unordered">
    <!-- If there's a block element somewhere in the step list, expand the whole list -->
    <xsl:variable name="step_expand"> <!-- set & save step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates select="." mode="common-processing-within-steps">
      <xsl:with-param name="step_expand" select="$step_expand"/>
      <xsl:with-param name="list-type" select="'ul'"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- only 1 step - output as a para -->
  <xsl:template match="*[contains(@class,' task/step ')]" mode="onestep">
    <xsl:param name="step_expand"/>
    <para>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates/>
    </para>  
  </xsl:template>
  
  <!-- multiple steps - output as list items -->
  <!-- 3517050: move rev test into mode="steps-fmt" to avoid wrapping <li> in another element.
       Can deprecate this template which now simply passes processing on to steps-fmt? -->
  <xsl:template match="*[contains(@class,' task/step ')]" mode="steps">
    <xsl:param name="step_expand"/>
    <li>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class"><xsl:if test="$step_expand='yes'">stepexpand</xsl:if></xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates><xsl:with-param name="step_expand" select="$step_expand"/></xsl:apply-templates>
    </li>    
  </xsl:template>
  
  <xsl:template match="*" mode="add-step-importance-flag">
    <xsl:choose>
      <xsl:when test="@importance='optional'">
        <strong>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Optional'"/>
          </xsl:call-template>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'ColonSymbol'"/>
          </xsl:call-template><xsl:text> </xsl:text>
        </strong>
      </xsl:when>
      <xsl:when test="@importance='required'">
        <strong>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Required'"/>
          </xsl:call-template>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'ColonSymbol'"/>
          </xsl:call-template><xsl:text> </xsl:text>
        </strong>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
    
    <xsl:template match="*[contains(@class, ' task/cmd ')]" name="topic.task.cmd">
      <xsl:choose>
        <xsl:when test="@href and @keyref">
          <xsl:apply-templates select="." mode="turning-to-link">
            <xsl:with-param name="keys" select="@keyref"/>
            <xsl:with-param name="type" select="'ph'"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <span>
            <xsl:call-template name="commonattributes"/>
            <xsl:call-template name="setidaname"/> 
            <xsl:apply-templates/>  
          </span>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:call-template name="add-br-for-empty-cmd"/>
    </xsl:template>
    
    <xsl:template name="add-br-for-empty-cmd">
      <xsl:if test="string-length(normalize-space(.)) = 0">
        <br/>
      </xsl:if>
    </xsl:template>
  
  <!-- nested steps - 1 level of nesting only -->
  <xsl:template match="*[contains(@class,' task/substeps ')]" name="topic.task.substeps">
   <!-- If there's a block element somewhere in the step list, expand the whole list -->
    <xsl:variable name="sub_step_expand"> <!-- set & save sub_step_expand=yes/no for expanding/compacting list items -->
      <xsl:apply-templates select="." mode="make-steps-compact"/>
    </xsl:variable>
    
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <orderedlist>
      <xsl:if test="parent::*/parent::*[contains(@class,' task/steps ')]"> <!-- Is the grandparent an ordered step? -->
        <xsl:attribute name="type">a</xsl:attribute>            <!-- yup, letter these steps -->
      </xsl:if>                                                <!-- otherwise, default to numbered -->
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates>
        <xsl:with-param name="sub_step_expand" select="$sub_step_expand"/>
      </xsl:apply-templates>
    </orderedlist>  
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- 3517050 move rev test into mode="steps-fmt" to avoid wrapping <li> in another element.
       Can deprecate this template which now simply passes processing on to substep-fmt? -->
  <xsl:template match="*[contains(@class,' task/substep ')]" name="topic.task.substep">
    <xsl:param name="sub_step_expand"/>
    <li>
      <xsl:call-template name="commonattributes">
        <xsl:with-param name="default-output-class"><xsl:if test="$sub_step_expand='yes'">substepexpand</xsl:if></xsl:with-param>
      </xsl:call-template>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates select="." mode="add-step-importance-flag"/>
      <xsl:apply-templates>
        <xsl:with-param name="sub_step_expand"/>
      </xsl:apply-templates>
    </li>  
  </xsl:template>
  
  <!-- choices contain choice items -->
  <xsl:template match="*[contains(@class,' task/choices ')]" name="topic.task.choices">
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:call-template name="setaname"/>
    <bulletlist>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setid"/>
      <xsl:apply-templates/>
    </bulletlist>  
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <!-- task/choice - fall-thru -->
  
  <!-- choice table is like a simpletable - 2 columns, set heading -->
  <xsl:template match="*[contains(@class,' task/choicetable ')]" name="topic.task.choicetable">
   <!-- Find the total number of relative units for the table. If @relcolwidth="1* 2* 2*",
        the variable is set to 5. -->
   <xsl:variable name="totalwidth">
     <xsl:if test="@relcolwidth">
       <xsl:call-template name="find-total-table-width"/>
     </xsl:if>
   </xsl:variable>
   <!-- Find how much of the table each relative unit represents. If @relcolwidth is 1* 2* 2*,
        there are 5 units. So, each unit takes up 100/5, or 20% of the table. Default to 0,
        which the entries will ignore. -->
   <xsl:variable name="width-multiplier">
     <xsl:choose>
       <xsl:when test="@relcolwidth">
         <xsl:value-of select="100 div $totalwidth"/>
       </xsl:when>
       <xsl:otherwise>0</xsl:otherwise>
     </xsl:choose>
   </xsl:variable>
    
   <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
   <xsl:call-template name="setaname"/>
     
   <table border="1" frame="hsides" rules="rows" cellpadding="4" cellspacing="0" summary="" class="choicetableborder">
    <xsl:call-template name="commonattributes"/>
    <xsl:apply-templates select="." mode="generate-table-summary-attribute"/>
    <xsl:call-template name="setid"/>  
    <!--If the choicetable has no header - output a default one-->
    <xsl:choose>
    <xsl:when test="not(./*[contains(@class,' task/chhead ')])">
     <thead>
       <tr>
         <th id="{generate-id(.)}-option" valign="bottom">
          <xsl:call-template name="th-align"/>
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Option'"/>
          </xsl:call-template>
         </th>  
         <th id="{generate-id(.)}-desc" valign="bottom">
           <xsl:call-template name="th-align"/>
           <xsl:call-template name="getVariable">
             <xsl:with-param name="id" select="'Description'"/>
           </xsl:call-template>
         </th>
       </tr>
     </thead>  
    </xsl:when>
    <xsl:otherwise>
     <thead>
       <tr>
         <xsl:for-each select="*[contains(@class,' task/chhead ')]">
           <xsl:call-template name="commonattributes"/>
         </xsl:for-each>
          <xsl:apply-templates select="*[contains(@class,' task/chhead ')]/*[contains(@class,' ditaot-d/ditaval-startprop ')]/@outputclass" mode="add-ditaval-style"/>
          <th valign="bottom">     
           <xsl:call-template name="th-align"/>
           <xsl:attribute name="id">     
           <xsl:choose>
            <!-- if the option header has an ID, use that -->
            <xsl:when test="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]/@id">
             <xsl:value-of select="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]/@id"/><xsl:text>-option</xsl:text>
            </xsl:when>
            <xsl:otherwise>  <!-- output a default option header ID -->
             <xsl:value-of select="generate-id(.)"/><xsl:text>-option</xsl:text>
            </xsl:otherwise>
           </xsl:choose>
           </xsl:attribute>
           <xsl:apply-templates select="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]" mode="chtabhdr"/>
          </th>  
          <th valign="bottom">     
           <xsl:call-template name="th-align"/>
           <xsl:attribute name="id">
           <xsl:choose>
            <!-- if the description header has an ID, use that -->
            <xsl:when test="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]/@id">
             <xsl:value-of select="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]/@id"/><xsl:text>-desc</xsl:text>
            </xsl:when>
            <xsl:otherwise>  <!-- output a default descr header ID -->
             <xsl:value-of select="generate-id(.)"/><xsl:text>-desc</xsl:text>
            </xsl:otherwise>
           </xsl:choose>
           </xsl:attribute>
           <xsl:apply-templates select="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]" mode="chtabhdr"/>
          </th>
       </tr>
     </thead>  
    </xsl:otherwise>
    </xsl:choose>
    <tbody>
      <xsl:apply-templates>     <!-- width-multiplier will be used in the first row to set widths. -->
        <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
      </xsl:apply-templates>
    </tbody>
   </table>  
    <xsl:apply-templates select="*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' task/choicetable ')]" mode="get-output-class">choicetableborder</xsl:template>
   
  <!-- headers are called above, hide the fall thru -->
  <xsl:template match="*[contains(@class,' task/chhead ')]" />
  <xsl:template match="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]" />
  <xsl:template match="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]" />
  
  <!-- Option & Description headers -->
  <xsl:template match="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]" mode="chtabhdr">
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  <xsl:template match="*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]" mode="chtabhdr">
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
    <xsl:apply-templates/>
    <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/chrow ')]" name="topic.task.chrow">
    <xsl:param name="width-multiplier" select="0"/>
    <tr>
      <xsl:call-template name="setid"/>
      <xsl:call-template name="commonattributes"/>    
      <xsl:apply-templates>     <!-- width-multiplier will be used in the first row to set widths. -->
        <xsl:with-param name="width-multiplier" select="$width-multiplier"/>
      </xsl:apply-templates>
    </tr>
  </xsl:template>
  
  <!-- specialization of stentry - choption -->
  <!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
  <!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
  <xsl:template match="*[contains(@class,' task/choption ')]" name="topic.task.choption">
   <xsl:param name="width-multiplier" select="0"/>
    
    <td valign="top">
     <!-- Add header attr for column header -->
     <xsl:attribute name="headers">
      <xsl:choose>
        <!-- First choice: if there is a user-specified header, and it has an ID -->
        <xsl:when test="ancestor::*[contains(@class,' task/choicetable ')]/*[contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]/@id">
          <xsl:value-of select="ancestor::*[contains(@class,' task/choicetable ')]/*[1][contains(@class,' task/chhead ')]/*[contains(@class,' task/choptionhd ')]/@id"/><xsl:text>-option</xsl:text>
        </xsl:when>
        <!-- Second choice: no user-specified header for this column. ID is based on the table's generated ID. -->
        <xsl:otherwise>
          <xsl:value-of select="generate-id(ancestor::*[contains(@class,' task/choicetable ')])"/><xsl:text>-option</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
     </xsl:attribute>
     <!-- Add header attr, column header then row header -->
     <xsl:attribute name="id">
      <!-- If there is a user-specified ID, use it -->
      <xsl:choose>
        <xsl:when test="@id">
          <xsl:value-of select="@id"/>
        </xsl:when>
        <xsl:otherwise> <!-- generate one -->
          <xsl:value-of select="generate-id(.)"/>
        </xsl:otherwise>
      </xsl:choose>
     </xsl:attribute>
      <xsl:call-template name="commonattributes"/>
      <xsl:variable name="localkeycol">
        <xsl:choose>
          <xsl:when test="ancestor::*[contains(@class,' topic/simpletable ')]/@keycol">
            <xsl:value-of select="ancestor::*[contains(@class,' topic/simpletable ')]/@keycol"/>
          </xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Determine which column this entry is in. -->
      <xsl:variable name="thiscolnum" select="count(preceding-sibling::*[contains(@class,' topic/stentry ')]) + 1"/>
      <!-- If width-multiplier=0, then either @relcolwidth was not specified, or this is not the first
           row, so do not create a width value. Otherwise, find out the relative width of this column. -->
      <xsl:variable name="widthpercent">
        <xsl:if test="$width-multiplier != 0">
          <xsl:call-template name="get-current-entry-percentage">
            <xsl:with-param name="multiplier"><xsl:value-of select="$width-multiplier"/></xsl:with-param>
            <xsl:with-param name="entry-num"><xsl:value-of select="$thiscolnum"/></xsl:with-param>
          </xsl:call-template>
        </xsl:if>
      </xsl:variable>
      <!-- If we calculated a width, create the width attribute. -->
      <xsl:if test="string-length($widthpercent)>0">
        <xsl:attribute name="width">
          <xsl:value-of select="$widthpercent"/><xsl:text>%</xsl:text>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <!-- Does the column match? Is REV on for entry or row? -->
      <xsl:choose>
       <xsl:when test="$thiscolnum=$localkeycol">
        <strong>
          <xsl:call-template name="stentry-templates"/>
        </strong>
       </xsl:when>
       <xsl:otherwise>
         <xsl:call-template name="stentry-templates"/>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </td>  
  </xsl:template>
  
  <!-- specialization of stentry - chdesc -->
  <!-- for specentry - if no text in cell, output specentry attr; otherwise output text -->
  <!-- Bold the @keycol column. Get the column's number. When (Nth stentry = the @keycol value) then bold the stentry -->
  <xsl:template match="*[contains(@class,' task/chdesc ')]" name="topic.task.chdesc">
   <xsl:param name="width-multiplier" select="0"/>
      
    <td valign="top">
     <!-- Add header attr, column header then option header -->
     <xsl:attribute name="headers">
      <xsl:choose>
        <!-- First choice: if there is a user-specified header, and it has an ID-->
        <xsl:when test="ancestor::*[contains(@class,' task/choicetable ')]/*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]/@id">
         <!-- If there is a user-specified row ID -->
          <xsl:value-of select="ancestor::*[contains(@class,' task/choicetable ')]/*[contains(@class,' task/chhead ')]/*[contains(@class,' task/chdeschd ')]/@id"/><xsl:text>-desc </xsl:text>
          <!-- add CHOption ID -->
          <xsl:choose>
           <xsl:when test="../*[contains(@class,' task/choption ')]/@id">
            <xsl:value-of select="../*[contains(@class,' task/choption ')]/@id"/>
           </xsl:when>
           <xsl:otherwise>
            <xsl:value-of select="generate-id(../*[contains(@class,' task/choption ')])"/>
           </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <!-- Second choice: no user-specified header for this column. ID is based on the table's generated ID. -->
        <xsl:otherwise>
          <xsl:value-of select="generate-id(ancestor::*[contains(@class,' task/choicetable ')])"/><xsl:text>-desc </xsl:text>
          <!-- add CHOption ID -->
          <xsl:choose>
           <xsl:when test="../*[contains(@class,' task/choption ')]/@id">
            <xsl:value-of select="../*[contains(@class,' task/choption ')]/@id"/>
           </xsl:when>
           <xsl:otherwise>
            <xsl:value-of select="generate-id(../*[contains(@class,' task/choption ')])"/>
           </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
     </xsl:attribute>
     <!-- If there is a user-specified ID, add it -->
     <xsl:if test="@id">
      <xsl:attribute name="id">
       <xsl:value-of select="@id"/>
      </xsl:attribute>
     </xsl:if>
     <xsl:call-template name="commonattributes"/>
      <xsl:variable name="localkeycol">
        <xsl:choose>
          <xsl:when test="ancestor::*[contains(@class,' topic/simpletable ')]/@keycol">
            <xsl:value-of select="ancestor::*[contains(@class,' topic/simpletable ')]/@keycol"/>
          </xsl:when>
          <xsl:otherwise>0</xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <!-- Determine which column this entry is in. -->
      <xsl:variable name="thiscolnum" select="number(count(preceding-sibling::*[contains(@class,' topic/stentry ')])+1)"/>
      <!-- If width-multiplier=0, then either @relcolwidth was not specified, or this is not the first
           row, so do not create a width value. Otherwise, find out the relative width of this column. -->
      <xsl:variable name="widthpercent">
        <xsl:if test="$width-multiplier != 0">
          <xsl:call-template name="get-current-entry-percentage">
            <xsl:with-param name="multiplier" select="$width-multiplier"/>
            <xsl:with-param name="entry-num" select="$thiscolnum"/>
          </xsl:call-template>
        </xsl:if>
      </xsl:variable>
      <!-- If we calculated a width, create the width attribute. -->
      <xsl:if test="string-length($widthpercent)>0">
        <xsl:attribute name="width">
          <xsl:value-of select="$widthpercent"/>
          <xsl:text>%</xsl:text>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>
      <!-- Does the column match? Is REV on for entry or row? -->
      <xsl:choose>
       <xsl:when test="$thiscolnum=$localkeycol">
        <strong>
          <xsl:call-template name="stentry-templates"/>
        </strong>
       </xsl:when>
       <xsl:otherwise>
         <xsl:call-template name="stentry-templates"/>
       </xsl:otherwise>
      </xsl:choose>
      <xsl:apply-templates select="../*[contains(@class,' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>
    </td>  
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepxmp ')]" name="topic.task.stepxmp">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/stepresult ')]" name="topic.task.stepresult">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/info ')]" name="topic.task.info">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/tutorialinfo ')]" name="topic.task.tutorialinfo">
    <xsl:call-template name="generateItemGroupTaskElement"/>
  </xsl:template>
  
  <xsl:template name="generateItemGroupTaskElement">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/prereq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_prereq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/context ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_context'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
      
  <xsl:template match="*[contains(@class,' task/result ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_results'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/postreq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_postreq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/taskbody ')]/*[contains(@class,' topic/example ')][not(*[contains(@class,' topic/title ')])]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_example'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!-- 
       To override the task label for a specific element, match that element with this mode. 
       For example, you can turn off labels for <context> with this rule:
       <xsl:template match="*[contains(@class,' task/context ')]" mode="generate-task-label"/>
  -->
  <xsl:template match="*" mode="generate-task-label">
    <xsl:param name="use-label"/>
    <xsl:if test="$GENERATE-TASK-LABELS='YES'">
      <xsl:variable name="headLevel">
        <xsl:variable name="headCount">
          <xsl:value-of select="count(ancestor::*[contains(@class,' topic/topic ')])+1"/>
        </xsl:variable>
        <xsl:choose>
          <xsl:when test="$headCount > 6">h6</xsl:when>
          <xsl:otherwise>h<xsl:value-of select="$headCount"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <div class="tasklabel">
        <xsl:element name="{$headLevel}">
          <xsl:attribute name="class">sectiontitle tasklabel</xsl:attribute>
          <xsl:value-of select="$use-label"/>
        </xsl:element>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- Tasks have their own group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group"
                name="related-links:group.task"
                as="xs:string">
    <xsl:text>task</xsl:text>
  </xsl:template>
  
  <!-- Priority of task group. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:get-group-priority"
                name="related-links:group-priority.task"
                as="xs:integer">
    <xsl:sequence select="2"/>
  </xsl:template>
  
  <!-- Task wrapper for HTML: "Related tasks" in <div>. -->
  <xsl:template match="*[contains(@class, ' topic/link ')][@type='task']" mode="related-links:result-group"
                name="related-links:result.task" as="element(linklist)">
    <xsl:param name="links" as="node()*"/>
    <xsl:if test="normalize-space(string-join($links, ''))">
      <linklist class="- topic/linklist " outputclass="relinfo reltasks">
        <title class="- topic/title ">
          <xsl:call-template name="getVariable">
            <xsl:with-param name="id" select="'Related tasks'"/>
          </xsl:call-template>
        </title>
        <xsl:copy-of select="$links"/>
      </linklist>
    </xsl:if>
  </xsl:template>
  
</xsl:stylesheet>
